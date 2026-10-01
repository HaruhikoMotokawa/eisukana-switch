import CoreGraphics
import OSLog

/// 入力ソースを英数 / かなへ切り替える。#3 の検出結果はここへ入ってくる。
@MainActor
protocol InputSourceSwitching: AnyObject {
    /// 切り替えのキーを送る。送れなかったら false。
    @discardableResult
    func activate(_ target: InputSourceTarget) -> Bool
}

extension InputSourceSwitching {
    /// 左 ⌘ なら英数、右 ⌘ ならかなへ切り替える（F-01 / F-02）。
    @discardableResult
    func activate(for side: CommandSide) -> Bool {
        activate(side.inputSourceTarget)
    }
}

/// JIS キーボードの「英数」「かな」キーを押したことにして切り替える（#32）。
///
/// `TISSelectInputSource` で IME を選ぶと、メニューバーの表示は変わっても、前面のアプリの
/// 入力モードは変わらない（macOS の既知の不具合）。キーを送れば、本物のキーを押したときと同じく
/// 前面のアプリの IME が受け取るので、確実に切り替わる。
///
/// 送るには「アクセシビリティ」（PostEvent）の許可が要る。未許可だとエラーも出ずに捨てられるので、
/// 許可の確認は呼ぶ側（`SwitchingController`）が先に済ませておく（Spike #1）。
@MainActor
final class JISKeySwitcher: InputSourceSwitching {
    func activate(_ target: InputSourceTarget) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: target.jisKeyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: target.jisKeyCode, keyDown: false)
        else {
            Logger.app.error("could not create the key events for \(target.rawValue, privacy: .public)")
            return false
        }
        // ⌘ を離した直後に送るので、修飾キーは付いていないはずだが、⌘ + 英数にならないよう明示しておく。
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        Logger.app.debug("posted \(target.rawValue, privacy: .public)")
        return true
    }
}
