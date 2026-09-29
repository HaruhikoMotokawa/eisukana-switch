import Foundation

/// 切り替え先の入力モード。
enum InputSourceTarget: String, CaseIterable, Sendable {
    /// 英数。IME の英数モード、または ABC などの ASCII 入力可能なキーボードレイアウト。
    case eisu
    /// かな。日本語 IME のひらがなモード。
    case kana
}

extension CommandSide {
    /// 既定の割り当て（F-01 / F-02）。左 ⌘ で英数、右 ⌘ でかなへ切り替える。
    /// 割り当てを変更できるようにするのは O-02（#14）。
    var inputSourceTarget: InputSourceTarget {
        switch self {
        case .left: .eisu
        case .right: .kana
        }
    }
}
