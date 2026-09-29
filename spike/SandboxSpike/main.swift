// Issue #1 検証用の使い捨てアプリ。App Sandbox 下で以下を確かめる。
//  - listen-only の CGEventTap で左右 ⌘ の単独押下を検出できるか
//  - 方式A: kVK_JIS_Eisu / kVK_JIS_Kana を CGEvent.post で送れるか
//  - 方式B: TISSelectInputSource で入力ソースを切り替えられるか
import Carbon
import Cocoa
import os

let logger = Logger(subsystem: "io.github.haruhikomotokawa.EisuKanaSwitch.Spike", category: "spike")
let logURL: URL = {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("spike.log")
}()

func log(_ message: String) {
    logger.log("\(message, privacy: .public)")
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? line.write(to: logURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Input sources

func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
    guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? String
}

func currentInputSourceID() -> String {
    stringProperty(TISCopyCurrentKeyboardInputSource().takeRetainedValue(), kTISPropertyInputSourceID) ?? "?"
}

func enabledSources() -> [TISInputSource] {
    TISCreateInputSourceList(nil, false).takeRetainedValue() as! [TISInputSource]
}

func findSource(eisu: Bool) -> TISInputSource? {
    let sources = enabledSources()
    let id = { (s: TISInputSource) in stringProperty(s, kTISPropertyInputSourceID) ?? "" }
    if eisu {
        return sources.first { id($0).hasSuffix(".Roman") } ?? sources.first { id($0) == "com.apple.keylayout.ABC" }
    }
    return sources.first { stringProperty($0, kTISPropertyInputModeID) == "com.apple.inputmethod.Japanese" }
}

// MARK: - Switching

enum Method: String, CaseIterable { case post = "A: CGEvent.post", tis = "B: TISSelectInputSource" }
var switchMethod: Method = .post

func switchInput(eisu: Bool, reason: String) {
    let before = currentInputSourceID()
    switch switchMethod {
    case .post:
        let code: CGKeyCode = eisu ? CGKeyCode(kVK_JIS_Eisu) : CGKeyCode(kVK_JIS_Kana)
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        log("[\(reason)] post \(eisu ? "Eisu" : "Kana") events created=\(down != nil && up != nil)")
    case .tis:
        guard let target = findSource(eisu: eisu) else { log("[\(reason)] TIS: target not found"); return }
        let status = TISSelectInputSource(target)
        log("[\(reason)] TIS select \(stringProperty(target, kTISPropertyInputSourceID) ?? "?") status=\(status)")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        log("[\(reason)] input source: \(before) -> \(currentInputSourceID())")
    }
}

// MARK: - Event tap

var tap: CFMachPort?
var pendingCommand: Int64?
var interrupted = false

func handle(type: CGEventType, event: CGEvent) {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        log("tap disabled (\(type.rawValue)); re-enabling")
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    case .flagsChanged:
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == kVK_Command || keyCode == kVK_RightCommand else {
            interrupted = true
            return
        }
        if event.flags.contains(.maskCommand), pendingCommand == nil {
            pendingCommand = keyCode
            interrupted = false
        } else if pendingCommand == keyCode {
            let isSolo = !interrupted
            log("\(keyCode == kVK_Command ? "Left" : "Right") ⌘ released solo=\(isSolo)")
            pendingCommand = nil
            if isSolo {
                DispatchQueue.main.async { switchInput(eisu: keyCode == kVK_Command, reason: "tap") }
            }
        } else {
            interrupted = true
        }
    default:
        if pendingCommand != nil { interrupted = true }
    }
}

func startTap() {
    guard tap == nil else { return }
    let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
    let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
    tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask,
        callback: { _, type, event, _ in
            handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }, userInfo: nil)
    guard let tap else { log("tapCreate FAILED (listen access=\(CGPreflightListenEventAccess()))"); return }
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    log("tapCreate OK")
}

// MARK: - Menu bar

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.title = "⌘英"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        let sandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        log("=== launch sandboxed=\(sandboxed) macOS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
        log("listen=\(CGPreflightListenEventAccess()) post=\(CGPreflightPostEventAccess()) AXTrusted=\(AXIsProcessTrusted())")
        log("sources: " + enabledSources().compactMap { stringProperty($0, kTISPropertyInputSourceID) }.joined(separator: ", "))
        log("current: \(currentInputSourceID())  log: \(logURL.path)")
        startTap()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: "入力監視: \(CGPreflightListenEventAccess() ? "許可" : "未許可")  タップ: \(tap != nil ? "動作中" : "なし")", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "イベント送信: \(CGPreflightPostEventAccess() ? "許可" : "未許可")", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, "入力監視を要求", #selector(requestListen))
        add(menu, "イベント送信を要求", #selector(requestPost))
        add(menu, "タップを開始", #selector(retryTap))
        menu.addItem(.separator())
        for (i, m) in Method.allCases.enumerated() {
            let mi = add(menu, "方式 \(m.rawValue)", #selector(selectMethod(_:)))
            mi.tag = i
            mi.state = m == switchMethod ? .on : .off
        }
        menu.addItem(.separator())
        add(menu, "3秒後に英数へ（手動テスト）", #selector(testEisu))
        add(menu, "3秒後にかなへ（手動テスト）", #selector(testKana))
        add(menu, "ログを開く", #selector(openLog))
        add(menu, "終了", #selector(NSApplication.terminate(_:)))
    }

    @discardableResult
    func add(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let mi = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        mi.target = self
        return mi
    }

    @objc func requestListen() { log("CGRequestListenEventAccess -> \(CGRequestListenEventAccess())") }
    @objc func requestPost() { log("CGRequestPostEventAccess -> \(CGRequestPostEventAccess())") }
    @objc func retryTap() { startTap() }
    @objc func selectMethod(_ sender: NSMenuItem) {
        switchMethod = Method.allCases[sender.tag]
        log("method = \(switchMethod.rawValue)")
    }
    @objc func testEisu() { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { switchInput(eisu: true, reason: "manual") } }
    @objc func testKana() { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { switchInput(eisu: false, reason: "manual") } }
    @objc func openLog() { NSWorkspace.shared.open(logURL) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
