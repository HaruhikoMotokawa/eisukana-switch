import Testing
@testable import EisuKanaSwitch

@Suite("英数への切り替え先の決定")
struct EisuSelectionTests {
    private func selection(
        current: InputSourceDescriptor?,
        enabled: [InputSourceDescriptor],
        asciiCapableSourceID: String? = nil
    ) -> InputSourceSelection {
        InputSourceSelector.selection(
            for: .eisu,
            current: current,
            enabled: enabled,
            asciiCapableSourceID: asciiCapableSourceID
        )
    }

    @Test("ことえりのひらがなからは ABC へ切り替わる（既定の macOS ではこれが通常の経路）")
    func fromKotoeriHiraganaFallsBackToABC() {
        let result = selection(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: InputSourceFixtures.kotoeriOnly
        )
        #expect(result == .select(InputSourceFixtures.abc))
    }

    @Test("同じ IME の英数モードが有効なら、そちらを優先する")
    func prefersRomanModeOfSameInputMethod() {
        let result = selection(
            current: InputSourceFixtures.googleHiragana,
            enabled: InputSourceFixtures.googleWithRoman
        )
        #expect(result == .select(InputSourceFixtures.googleRoman))
    }

    @Test("他の IME の英数モードしか無ければ、それを選ぶ")
    func fallsBackToRomanModeOfAnotherInputMethod() {
        let result = selection(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: [InputSourceFixtures.kotoeriHiragana, InputSourceFixtures.atokRoman]
        )
        #expect(result == .select(InputSourceFixtures.atokRoman))
    }

    @Test("直近に使った ASCII レイアウトがあれば、ABC より優先する")
    func prefersRecentASCIILayoutOverABC() {
        let result = selection(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: [InputSourceFixtures.abc, InputSourceFixtures.dvorak, InputSourceFixtures.kotoeriHiragana],
            asciiCapableSourceID: InputSourceFixtures.dvorak.id
        )
        #expect(result == .select(InputSourceFixtures.dvorak))
    }

    @Test("直近の ASCII レイアウトが有効一覧に無ければ、ABC へ落とす")
    func ignoresASCIIHintWhenNotEnabled() {
        let result = selection(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: InputSourceFixtures.kotoeriOnly,
            asciiCapableSourceID: InputSourceFixtures.dvorak.id
        )
        #expect(result == .select(InputSourceFixtures.abc))
    }

    @Test("ABC が無ければ、ASCII を打てる他のレイアウトを選ぶ")
    func fallsBackToAnyASCIILayout() {
        let result = selection(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: [InputSourceFixtures.russian, InputSourceFixtures.dvorak, InputSourceFixtures.kotoeriHiragana]
        )
        #expect(result == .select(InputSourceFixtures.dvorak))
    }

    @Test("すでに ABC なら何もしない")
    func noOpWhenAlreadyOnLatinLayout() {
        let result = selection(current: InputSourceFixtures.abc, enabled: InputSourceFixtures.kotoeriOnly)
        #expect(result == .alreadyActive)
    }

    @Test("すでに IME の英数モードなら何もしない")
    func noOpWhenAlreadyInRomanMode() {
        let result = selection(
            current: InputSourceFixtures.googleRoman,
            enabled: InputSourceFixtures.googleWithRoman
        )
        #expect(result == .alreadyActive)
    }

    @Test("カタカナなど、ひらがな以外の日本語モードからも英数へ抜けられる")
    func switchesAwayFromKatakana() {
        let result = selection(
            current: InputSourceFixtures.kotoeriKatakana,
            enabled: InputSourceFixtures.kotoeriOnly
        )
        #expect(result == .select(InputSourceFixtures.abc))
    }

    @Test("英数の候補がひとつも無ければ noCandidate")
    func noCandidateWhenOnlyJapaneseSourcesAreEnabled() {
        let result = selection(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: InputSourceFixtures.japaneseOnly
        )
        #expect(result == .noCandidate)
    }

    @Test("現在の入力ソースが読めなくても、候補があれば切り替える")
    func worksWithoutCurrentSource() {
        let result = selection(current: nil, enabled: InputSourceFixtures.kotoeriOnly)
        #expect(result == .select(InputSourceFixtures.abc))
    }
}

@Suite("かなへの切り替え先の決定")
struct KanaSelectionTests {
    private func selection(
        current: InputSourceDescriptor?,
        enabled: [InputSourceDescriptor],
        preferredKanaBundleID: String? = nil
    ) -> InputSourceSelection {
        InputSourceSelector.selection(
            for: .kana,
            current: current,
            enabled: enabled,
            preferredKanaBundleID: preferredKanaBundleID
        )
    }

    @Test("ABC からは、有効なひらがなの入力ソースへ切り替わる")
    func fromABCSelectsHiragana() {
        let result = selection(current: InputSourceFixtures.abc, enabled: InputSourceFixtures.kotoeriOnly)
        #expect(result == .select(InputSourceFixtures.kotoeriHiragana))
    }

    @Test("同じ IME の英数モードからは、その IME のひらがなへ戻る")
    func returnsToHiraganaOfSameInputMethod() {
        let result = selection(
            current: InputSourceFixtures.googleRoman,
            enabled: [
                InputSourceFixtures.kotoeriHiragana,
                InputSourceFixtures.googleHiragana,
                InputSourceFixtures.googleRoman,
            ]
        )
        #expect(result == .select(InputSourceFixtures.googleHiragana))
    }

    @Test("複数の IME が有効なときは、直前に使っていた IME へ戻る")
    func prefersRememberedInputMethod() {
        let result = selection(
            current: InputSourceFixtures.abc,
            enabled: [
                InputSourceFixtures.abc,
                InputSourceFixtures.kotoeriHiragana,
                InputSourceFixtures.googleHiragana,
            ],
            preferredKanaBundleID: InputSourceFixtures.googleHiragana.bundleID
        )
        #expect(result == .select(InputSourceFixtures.googleHiragana))
    }

    @Test("覚えている IME が無効になっていたら、一覧の先頭のひらがなを選ぶ")
    func fallsBackWhenRememberedInputMethodIsGone() {
        let result = selection(
            current: InputSourceFixtures.abc,
            enabled: InputSourceFixtures.kotoeriOnly,
            preferredKanaBundleID: InputSourceFixtures.googleHiragana.bundleID
        )
        #expect(result == .select(InputSourceFixtures.kotoeriHiragana))
    }

    @Test("すでにひらがななら何もしない")
    func noOpWhenAlreadyHiragana() {
        let result = selection(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: InputSourceFixtures.kotoeriOnly
        )
        #expect(result == .alreadyActive)
    }

    @Test("カタカナからはひらがなへ切り替わる")
    func switchesFromKatakanaToHiragana() {
        let result = selection(
            current: InputSourceFixtures.kotoeriKatakana,
            enabled: InputSourceFixtures.kotoeriOnly
        )
        #expect(result == .select(InputSourceFixtures.kotoeriHiragana))
    }

    @Test("日本語 IME がひとつも有効でなければ noCandidate")
    func noCandidateWithoutJapaneseInputMethod() {
        let result = selection(current: InputSourceFixtures.abc, enabled: [InputSourceFixtures.abc])
        #expect(result == .noCandidate)
    }
}

@Suite("左右 ⌘ の割り当て")
struct CommandSideAssignmentTests {
    @Test("左 ⌘ は英数、右 ⌘ はかな（F-01 / F-02）")
    func defaultAssignment() {
        #expect(CommandSide.left.inputSourceTarget == .eisu)
        #expect(CommandSide.right.inputSourceTarget == .kana)
    }
}
