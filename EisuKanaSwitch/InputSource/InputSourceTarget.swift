import Carbon.HIToolbox
import CoreGraphics

/// 切り替え先の入力モード。
enum InputSourceTarget: String, CaseIterable, Sendable {
    /// 英数。
    case eisu
    /// かな。
    case kana

    /// JIS キーボードの「英数」「かな」キー。どの入力ソースへ移るかは IME に任せる（#32）。
    var jisKeyCode: CGKeyCode {
        switch self {
        case .eisu: CGKeyCode(kVK_JIS_Eisu)
        case .kana: CGKeyCode(kVK_JIS_Kana)
        }
    }
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
