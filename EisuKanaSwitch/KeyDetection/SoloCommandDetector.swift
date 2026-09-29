/// 判定に使う修飾キー。
///
/// Caps Lock（`maskAlphaShift`）は意図的に含めない。ロック状態であって同時押しではないため、
/// 他の修飾キーとして扱うと Caps Lock が ON の間ずっと切り替えが起きなくなってしまう。
struct ModifierFlags: OptionSet, Equatable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let command = ModifierFlags(rawValue: 1 << 0)
    static let shift = ModifierFlags(rawValue: 1 << 1)
    static let control = ModifierFlags(rawValue: 1 << 2)
    static let option = ModifierFlags(rawValue: 1 << 3)
    static let fn = ModifierFlags(rawValue: 1 << 4)
}

/// 判定の入力。CGEvent はここまでで正規化しておく。
enum InputEvent: Equatable {
    /// 修飾キーの状態が変わった（`flagsChanged`）。
    case modifiersChanged(keyCode: Int64, flags: ModifierFlags)
    /// 修飾キー以外の入力（キー入力・クリック・スクロール）。
    case otherInput
}

/// 左右 ⌘ の単独押下（押して、何もせずに離す）を判定する状態機械。
///
/// CoreGraphics には依存しない純粋な値型にして、ユニットテストから入力を流し込めるようにしている。
struct SoloCommandDetector {
    enum State: Equatable {
        /// 候補なし。
        case idle
        /// ⌘ が 1 つだけ押されていて、まだ何も邪魔が入っていない。
        case armed(CommandSide)
        /// 対象外が確定した。修飾キーが全部離されるまでこのまま。
        case disqualified
    }

    private(set) var state: State = .idle

    /// イベントを 1 つ処理する。単独押下が成立したときだけ、その左右を返す。
    mutating func handle(_ event: InputEvent) -> CommandSide? {
        switch event {
        case .otherInput:
            // ⌘ を押している間の他の入力は、ショートカットやクリックなので対象外にする（F-03）。
            if case .armed = state { state = .disqualified }
            return nil
        case let .modifiersChanged(keyCode, flags):
            return handleModifiersChanged(keyCode: keyCode, flags: flags)
        }
    }

    /// タップの再有効化やスリープ復帰など、イベントを取りこぼした可能性があるときに状態を捨てる。
    mutating func reset() {
        state = .idle
    }

    private mutating func handleModifiersChanged(keyCode: Int64, flags: ModifierFlags) -> CommandSide? {
        let side = CommandSide(keyCode: keyCode)

        // 押していた ⌘ が、他の修飾キーを伴わずに離された → 成立。
        if case let .armed(armedSide) = state, side == armedSide, flags.isEmpty {
            state = .idle
            return armedSide
        }

        // 修飾キーが全て離された。disqualified からの唯一の復帰経路。
        if flags.isEmpty {
            state = .idle
            return nil
        }

        // ⌘ だけが押された。
        if let side, flags == .command, state == .idle {
            state = .armed(side)
            return nil
        }

        // 他の修飾キーとの同時押し、左右 ⌘ の同時押し、disqualified 中の変化。
        state = .disqualified
        return nil
    }
}
