import Foundation

/// セレクタの判断。
enum InputSourceSelection: Equatable, Sendable {
    /// すでに目的のモードなので、切り替えない。
    case alreadyActive
    /// この入力ソースを選ぶ。
    case select(InputSourceDescriptor)
    /// 有効な入力ソースの中に候補が無い。
    case noCandidate
}

/// 現在の入力ソースと有効な入力ソースの一覧から、切り替え先を決める純粋関数。
///
/// 判定のルールは #4 のコメントに書いたとおり。要点は 2 つ。
/// - 無効な入力ソースは `TISSelectInputSource` で選べない（`paramErr` になる）ので、
///   候補は有効なものだけに限る。最近の macOS ではことえりの英数モードが無効なため、
///   英数へは ABC などのキーボードレイアウトで切り替わることが多い。
/// - 同じ IME の中で行き来できるときはそれを優先し、IME の文脈を保つ。
enum InputSourceSelector {
    /// - Parameters:
    ///   - target: 切り替え先。
    ///   - current: 現在の入力ソース。取得できなければ nil。
    ///   - enabled: 有効かつ選択可能なキーボード入力ソース。ユーザーが並べた順。
    ///   - asciiCapableSourceID: `TISCopyCurrentASCIICapableKeyboardInputSource()` が指す ID。
    ///     直近に使った ASCII 入力可能なキーボードレイアウトなので、ABC より先に見る。
    ///   - preferredKanaBundleID: 直前に離れたかな入力ソースのバンドル ID。
    ///     複数の IME を有効にしていても、元の IME に戻れるようにするための手がかり。
    static func selection(
        for target: InputSourceTarget,
        current: InputSourceDescriptor?,
        enabled: [InputSourceDescriptor],
        asciiCapableSourceID: String? = nil,
        preferredKanaBundleID: String? = nil
    ) -> InputSourceSelection {
        switch target {
        case .eisu:
            eisuSelection(current: current, enabled: enabled, asciiCapableSourceID: asciiCapableSourceID)
        case .kana:
            kanaSelection(current: current, enabled: enabled, preferredKanaBundleID: preferredKanaBundleID)
        }
    }

    private static func eisuSelection(
        current: InputSourceDescriptor?,
        enabled: [InputSourceDescriptor],
        asciiCapableSourceID: String?
    ) -> InputSourceSelection {
        if let current, current.isEisu { return .alreadyActive }

        let romanModes = enabled.filter(\.isRomanMode)
        // 同じ IME の英数モードがあれば、それが一番自然な戻り先。
        if let bundleID = current?.bundleID,
           let sibling = romanModes.first(where: { $0.bundleID == bundleID }) {
            return .select(sibling)
        }
        if let anyRoman = romanModes.first {
            return .select(anyRoman)
        }

        let latinLayouts = enabled.filter(\.isLatinKeyboardLayout)
        // ABC 決め打ちにすると、Dvorak などを使っている人のレイアウトを奪ってしまう。
        if let asciiCapableSourceID,
           let recent = latinLayouts.first(where: { $0.id == asciiCapableSourceID }) {
            return .select(recent)
        }
        if let abc = latinLayouts.first(where: { $0.id == Self.abcKeyboardLayoutID }) {
            return .select(abc)
        }
        if let anyLatin = latinLayouts.first {
            return .select(anyLatin)
        }
        return .noCandidate
    }

    private static func kanaSelection(
        current: InputSourceDescriptor?,
        enabled: [InputSourceDescriptor],
        preferredKanaBundleID: String?
    ) -> InputSourceSelection {
        if let current, current.isKanaMode { return .alreadyActive }

        let kanaModes = enabled.filter(\.isKanaMode)
        // 英数モードからの復帰。同じ IME のひらがなへ戻す。
        if let bundleID = current?.bundleID,
           let sibling = kanaModes.first(where: { $0.bundleID == bundleID }) {
            return .select(sibling)
        }
        // ABC から戻るときは、直前に使っていた IME を覚えておいて選ぶ。
        if let preferredKanaBundleID,
           let remembered = kanaModes.first(where: { $0.bundleID == preferredKanaBundleID }) {
            return .select(remembered)
        }
        if let anyKana = kanaModes.first {
            return .select(anyKana)
        }
        return .noCandidate
    }

    /// 最後の頼みの綱。macOS に必ず入っている ASCII 入力可能なキーボードレイアウト。
    static let abcKeyboardLayoutID = "com.apple.keylayout.ABC"
}
