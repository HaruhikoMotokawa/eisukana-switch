import Foundation
import Testing
@testable import EisuKanaSwitch

/// `CGEventTap` は作らず、開始 / 停止の呼ばれ方だけを記録する。
@MainActor
final class FakeCommandKeyMonitor: CommandKeyMonitoring {
    var onSoloCommand: ((CommandSide) -> Void)?
    var onPermissionLost: (() -> Void)?
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    @discardableResult
    func start() -> Bool {
        startCount += 1
        isRunning = true
        return true
    }

    func stop() {
        stopCount += 1
        isRunning = false
    }

    /// タップからの通知を模して、単独押下を流し込む。
    func emit(_ side: CommandSide) {
        onSoloCommand?(side)
    }

    /// 監視中に許可が外れて、監視が止まった状況を再現する。
    func losePermission() {
        stop()
        onPermissionLost?()
    }
}

/// 入力監視の許可を、テストから自由に動かせるようにする。
@MainActor
final class FakeInputMonitoringPermission: InputMonitoringPermitting {
    var isGranted: Bool
    private(set) var requestCount = 0
    private(set) var openSettingsCount = 0
    private(set) var isWatching = false
    private var onChange: ((Bool) -> Void)?

    init(isGranted: Bool = true) {
        self.isGranted = isGranted
    }

    func request() {
        requestCount += 1
    }

    func openSystemSettings() {
        openSettingsCount += 1
    }

    func startWatching(onChange: @escaping (Bool) -> Void) {
        isWatching = true
        self.onChange = onChange
    }

    func stopWatching() {
        isWatching = false
        onChange = nil
    }

    /// ユーザーがシステム設定で許可状態を変えた、という想定で通知する。
    func change(to granted: Bool) {
        isGranted = granted
        guard isWatching else { return }
        onChange?(granted)
    }
}

/// `UserDefaults` を触らずに、保存された値だけを持つ。
@MainActor
final class FakeEnabledStateStore: EnabledStateStore {
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}

/// 入力ソースには触らず、切り替えの要求だけを記録する。
@MainActor
final class FakeInputSourceSwitcher: InputSourceSwitching {
    private(set) var activated: [InputSourceTarget] = []

    @discardableResult
    func activate(_ target: InputSourceTarget) -> InputSourceSwitchResult {
        activated.append(target)
        return .switched(id: target.rawValue)
    }
}

@Suite("SwitchingController")
@MainActor
struct SwitchingControllerTests {
    /// テスト対象と、覗き込むためのフェイクをまとめて作る。
    private static func make(
        storedIsEnabled: Bool = true,
        isGranted: Bool = true
    ) -> (
        SwitchingController,
        FakeCommandKeyMonitor,
        FakeInputSourceSwitcher,
        FakeEnabledStateStore,
        FakeInputMonitoringPermission
    ) {
        let monitor = FakeCommandKeyMonitor()
        let switcher = FakeInputSourceSwitcher()
        let store = FakeEnabledStateStore(isEnabled: storedIsEnabled)
        let permission = FakeInputMonitoringPermission(isGranted: isGranted)
        let controller = SwitchingController(
            monitor: monitor,
            switcher: switcher,
            store: store,
            permission: permission
        )
        return (controller, monitor, switcher, store, permission)
    }

    @Test("保存された有効/無効を起動時に引き継ぐ")
    func restoresStoredState() {
        let (enabled, _, _, _, _) = Self.make(storedIsEnabled: true)
        #expect(enabled.isEnabled)

        let (disabled, _, _, _, _) = Self.make(storedIsEnabled: false)
        #expect(!disabled.isEnabled)
    }

    @Test("有効なら起動時に監視を始める")
    func startsMonitorWhenEnabled() {
        let (controller, monitor, _, _, _) = Self.make(storedIsEnabled: true)

        controller.start()

        #expect(monitor.isRunning)
        #expect(monitor.startCount == 1)
    }

    @Test("無効なら起動時に監視を始めない")
    func doesNotStartMonitorWhenDisabled() {
        let (controller, monitor, _, _, _) = Self.make(storedIsEnabled: false)

        controller.start()

        #expect(!monitor.isRunning)
        #expect(monitor.startCount == 0)
    }

    @Test("左 ⌘ で英数、右 ⌘ でかなへ切り替える")
    func activatesTargetForEachSide() {
        let (controller, monitor, switcher, _, _) = Self.make()
        controller.start()

        monitor.emit(.left)
        monitor.emit(.right)

        #expect(switcher.activated == [.eisu, .kana])
    }

    @Test("無効にすると監視を止め、設定を保存する")
    func disablingStopsMonitorAndPersists() {
        let (controller, monitor, _, store, _) = Self.make()
        controller.start()

        controller.setEnabled(false)

        #expect(!controller.isEnabled)
        #expect(!monitor.isRunning)
        #expect(monitor.stopCount == 1)
        #expect(!store.isEnabled)
    }

    @Test("有効に戻すと監視を再開し、設定を保存する")
    func enablingStartsMonitorAndPersists() {
        let (controller, monitor, _, store, _) = Self.make(storedIsEnabled: false)
        controller.start()

        controller.setEnabled(true)

        #expect(controller.isEnabled)
        #expect(monitor.isRunning)
        #expect(monitor.startCount == 1)
        #expect(store.isEnabled)
    }

    @Test("無効の間に届いたイベントでは切り替えない")
    func ignoresEventsWhileDisabled() {
        let (controller, monitor, switcher, _, _) = Self.make()
        controller.start()
        controller.setEnabled(false)

        monitor.emit(.left)

        #expect(switcher.activated.isEmpty)
    }

    @Test("同じ値をセットしても監視には触らない")
    func settingSameValueDoesNothing() {
        let (controller, monitor, _, _, _) = Self.make()
        controller.start()

        controller.setEnabled(true)

        #expect(monitor.startCount == 1)
        #expect(monitor.stopCount == 0)
    }

    @Test("入力監視が未許可なら監視を始めず、有効のまま許可を待つ")
    func waitsForPermissionWhenNotGranted() {
        let (controller, monitor, _, store, permission) = Self.make(isGranted: false)

        controller.start()

        #expect(!controller.hasInputMonitoringPermission)
        #expect(monitor.startCount == 0)
        // 未許可でも無効にはしない。許可されたらそのまま動き出す（F-06）。
        #expect(controller.isEnabled)
        #expect(store.isEnabled)
        #expect(permission.isWatching)
    }

    @Test("初回起動で未許可なら、システムの確認ダイアログを出す")
    func requestsPermissionOnLaunch() {
        let (controller, _, _, _, permission) = Self.make(isGranted: false)

        controller.start()

        #expect(permission.requestCount == 1)
    }

    @Test("許可されたら、再起動せずに監視を始める")
    func startsMonitorOncePermissionIsGranted() {
        let (controller, monitor, _, _, permission) = Self.make(isGranted: false)
        controller.start()

        permission.change(to: true)

        #expect(controller.hasInputMonitoringPermission)
        #expect(monitor.isRunning)
        #expect(monitor.startCount == 1)
        // 許可されたあとは見張らなくてよい。
        #expect(!permission.isWatching)
    }

    @Test("許可を待つ間に無効にされたら、許可されても監視は始めない")
    func doesNotStartMonitorWhenDisabledWhileWaiting() {
        let (controller, monitor, _, _, permission) = Self.make(isGranted: false)
        controller.start()

        controller.setEnabled(false)
        permission.change(to: true)

        #expect(!monitor.isRunning)
        #expect(monitor.startCount == 0)
    }

    @Test("無効にすると、許可を待つのもやめる")
    func disablingStopsWatchingPermission() {
        let (controller, _, _, _, permission) = Self.make(isGranted: false)
        controller.start()

        controller.setEnabled(false)

        #expect(!permission.isWatching)
    }

    @Test("「システム設定を開く」で設定を開き、許可を待ち始める")
    func openingSettingsStartsWatching() {
        let (controller, monitor, _, _, permission) = Self.make(isGranted: false)
        controller.start()

        controller.openInputMonitoringSettings()
        permission.change(to: true)

        #expect(permission.openSettingsCount == 1)
        #expect(monitor.isRunning)
    }

    @Test("監視中に許可が外れたら、状態に反映してまた許可を待つ")
    func reflectsRevokedPermission() {
        let (controller, monitor, _, _, permission) = Self.make()
        controller.start()

        monitor.losePermission()

        #expect(!controller.hasInputMonitoringPermission)
        #expect(!monitor.isRunning)
        #expect(permission.isWatching)

        // 許可し直されたら、また動き出す。
        permission.change(to: true)

        #expect(controller.hasInputMonitoringPermission)
        #expect(monitor.isRunning)
    }

    @Test("許可されているなら、待たずにそのまま監視を始める")
    func doesNotWatchWhenAlreadyGranted() {
        let (controller, monitor, _, _, permission) = Self.make()

        controller.start()

        #expect(controller.hasInputMonitoringPermission)
        #expect(monitor.isRunning)
        #expect(permission.requestCount == 0)
        #expect(!permission.isWatching)
    }

    @Test("終了時に監視を止める")
    func stopStopsMonitor() {
        let (controller, monitor, _, _, _) = Self.make()
        controller.start()

        controller.stop()

        #expect(!monitor.isRunning)
        #expect(monitor.stopCount == 1)
    }
}
