import AppKit
import CoreGraphics
import OSLog

/// 左右 ⌘ の単独押下を通知する監視。実装を差し替えてテストできるようにしている。
@MainActor
protocol CommandKeyMonitoring: AnyObject {
    /// 単独押下の通知先。監視を始める前に設定する。
    var onSoloCommand: ((CommandSide) -> Void)? { get set }
    /// 監視中か。
    var isRunning: Bool { get }
    /// 監視を開始する。開始できなければ false。
    @discardableResult
    func start() -> Bool
    /// 監視を止める。
    func stop()
}

/// listen-only の `CGEventTap` でキー入力を監視し、左右 ⌘ の単独押下を通知する。
///
/// イベントを止めたり書き換えたりはしないので、必要な権限は「入力監視」だけ（Spike #1）。
@MainActor
final class CommandKeyMonitor: CommandKeyMonitoring {
    var onSoloCommand: ((CommandSide) -> Void)?
    private var detector = SoloCommandDetector()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var wakeObserver: (any NSObjectProtocol)?

    var isRunning: Bool { tap != nil }

    init(onSoloCommand: ((CommandSide) -> Void)? = nil) {
        self.onSoloCommand = onSoloCommand
    }

    deinit {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        // コールバックには self のポインタを渡しているので、必ずタップを捨ててから解放されるようにする。
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
    }

    /// 監視を開始する。入力監視が未許可、またはタップを作れなかったときは false を返す。
    ///
    /// 未許可でも `CGEvent.tapCreate` 自体は成功してしまい、イベントが届かないまま
    /// `tapDisabledByUserInput` が繰り返されるので、事前に権限を確認する（Spike #1）。
    /// 権限の案内と、許可された後の再試行は #6 で扱う。
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard CGPreflightListenEventAccess() else {
            Logger.keyMonitor.notice("not starting: input monitoring is not granted")
            return false
        }

        let eventTypes: [CGEventType] = [
            .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
        ]
        let mask = eventTypes.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            // タップのソースはメインの run loop に追加しているので、必ずメインスレッドで呼ばれる。
            MainActor.assumeIsolated {
                let monitor = Unmanaged<CommandKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.keyMonitor.error("CGEvent.tapCreate failed")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        detector.reset()
        observeWakeIfNeeded()
        Logger.keyMonitor.notice("started")
        return true
    }

    /// 監視を止める。
    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        runLoopSource = nil
        detector.reset()
        Logger.keyMonitor.notice("stopped")
    }

    // MARK: - Events

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // 処理が重かったとき（timeout）や、ユーザー操作で無効化されたときに届く。
            reenable(reason: type == .tapDisabledByTimeout ? "timeout" : "user input")
        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            emit(detector.handle(.modifiersChanged(keyCode: keyCode, flags: ModifierFlags(event.flags))))
        default:
            emit(detector.handle(.otherInput))
        }
    }

    private func emit(_ side: CommandSide?) {
        guard let side else { return }
        Logger.keyMonitor.debug("solo command: \(String(describing: side), privacy: .public)")
        onSoloCommand?(side)
    }

    /// 無効化されたタップを有効に戻す。取りこぼしがあり得るので、状態機械は必ず捨てる。
    private func reenable(reason: String) {
        guard let tap else { return }
        // 入力監視が外されていると、再有効化してもイベントのたびに無効化されて堂々巡りになる。
        guard CGPreflightListenEventAccess() else {
            Logger.keyMonitor.error("tap disabled (\(reason, privacy: .public)) and input monitoring is not granted; stopping")
            stop()
            return
        }
        Logger.keyMonitor.notice("tap disabled (\(reason, privacy: .public)); re-enabling")
        CGEvent.tapEnable(tap: tap, enable: true)
        detector.reset()
    }

    /// スリープ復帰。スリープ中にキーを離したイベントを取りこぼしている可能性があるので、
    /// タップを有効に戻したうえで状態を捨てる。
    private func observeWakeIfNeeded() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reenable(reason: "wake from sleep")
            }
        }
    }
}

extension ModifierFlags {
    /// Caps Lock（`maskAlphaShift`）は意図的に読み取らない。
    init(_ flags: CGEventFlags) {
        var result: ModifierFlags = []
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskSecondaryFn) { result.insert(.fn) }
        self = result
    }
}
