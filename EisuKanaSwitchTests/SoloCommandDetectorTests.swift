import Testing
@testable import EisuKanaSwitch

@Suite("左右 ⌘ の単独押下の判定")
struct SoloCommandDetectorTests {
    /// イベント列を流し込んで、成立した単独押下だけを取り出す。
    private func detected(_ events: [InputEvent], on detector: inout SoloCommandDetector) -> [CommandSide] {
        events.compactMap { detector.handle($0) }
    }

    private func detected(_ events: [InputEvent]) -> [CommandSide] {
        var detector = SoloCommandDetector()
        return detected(events, on: &detector)
    }

    // MARK: - 成立するケース（F-01 / F-02）

    @Test("⌘ を押して離すと、その左右が返る", arguments: CommandSide.allCases)
    func soloPress(side: CommandSide) {
        #expect(detected([.press(side), .release(side)]) == [side])
    }

    @Test("続けて押した場合も、その都度成立する")
    func repeatedPresses() {
        #expect(detected([
            .press(.left), .release(.left),
            .press(.right), .release(.right),
            .press(.left), .release(.left),
        ]) == [.left, .right, .left])
    }

    // MARK: - 成立しないケース（F-03）

    @Test("⌘ を押している間のキー入力（⌘C）では成立しない")
    func commandWithKeyDown() {
        #expect(detected([.press(.left), .otherInput, .release(.left)]).isEmpty)
    }

    @Test("⌘ を押している間のクリックやスクロールでは成立しない")
    func commandWithMouseInput() {
        // クリックもスクロールも .otherInput に正規化される。複数回届いても同じ。
        #expect(detected([.press(.right), .otherInput, .otherInput, .release(.right)]).isEmpty)
    }

    @Test("他の修飾キーを後から押した場合は成立しない")
    func modifierPressedAfterCommand() {
        #expect(detected([
            .press(.left),
            .modifiersChanged(keyCode: shiftKeyCode, flags: [.command, .shift]),
            .modifiersChanged(keyCode: shiftKeyCode, flags: .command),
            .release(.left),
        ]).isEmpty)
    }

    @Test("他の修飾キーを先に押した場合は成立しない")
    func modifierPressedBeforeCommand() {
        #expect(detected([
            .modifiersChanged(keyCode: shiftKeyCode, flags: .shift),
            .modifiersChanged(keyCode: CommandSide.left.keyCode, flags: [.command, .shift]),
            .modifiersChanged(keyCode: CommandSide.left.keyCode, flags: .shift),
            .modifiersChanged(keyCode: shiftKeyCode, flags: []),
        ]).isEmpty)
    }

    @Test("⌘ を離すより先に他の修飾キーを離しても成立しない")
    func modifierReleasedBeforeCommand() {
        // ⇧ を離した時点で flags は .command に戻るが、判定をやり直してはいけない。
        var detector = SoloCommandDetector()
        let events: [InputEvent] = [
            .press(.right),
            .modifiersChanged(keyCode: shiftKeyCode, flags: [.command, .shift]),
            .modifiersChanged(keyCode: shiftKeyCode, flags: .command),
            .release(.right),
        ]
        #expect(detected(events, on: &detector).isEmpty)
        #expect(detector.state == .idle)
    }

    @Test("左右の ⌘ を同時に押した場合は成立しない")
    func bothCommandKeys() {
        #expect(detected([
            .press(.left),
            // 右 ⌘ を押しても離しても、flags には片方が残るので .command のまま。
            .modifiersChanged(keyCode: CommandSide.right.keyCode, flags: .command),
            .modifiersChanged(keyCode: CommandSide.right.keyCode, flags: .command),
            .release(.left),
        ]).isEmpty)
    }

    // MARK: - 状態の後始末

    @Test("対象外になった後も、次の単独押下は成立する")
    func recoversAfterDisqualified() {
        #expect(detected([
            .press(.left), .otherInput, .release(.left),
            .press(.left), .release(.left),
        ]) == [.left])
    }

    @Test("⌘ を押している途中で reset すると、その押下は成立しない")
    func resetDiscardsPendingPress() {
        var detector = SoloCommandDetector()
        _ = detector.handle(.press(.left))
        detector.reset()
        #expect(detector.state == .idle)
        #expect(detector.handle(.release(.left)) == nil)
        // reset 後も、次の単独押下は正しく拾える。
        #expect(detected([.press(.right), .release(.right)], on: &detector) == [.right])
    }

    @Test("押下を取りこぼして離すイベントだけが届いても、何も起きない")
    func releaseWithoutPress() {
        #expect(detected([.release(.left)]).isEmpty)
    }
}

// MARK: - Helpers

/// `kVK_Shift`
private let shiftKeyCode: Int64 = 56

private extension CommandSide {
    var keyCode: Int64 {
        switch self {
        case .left: Self.leftKeyCode
        case .right: Self.rightKeyCode
        }
    }
}

private extension InputEvent {
    /// ⌘ を単独で押したときの `flagsChanged`。
    static func press(_ side: CommandSide) -> InputEvent {
        .modifiersChanged(keyCode: side.keyCode, flags: .command)
    }

    /// ⌘ を単独で離したときの `flagsChanged`。
    static func release(_ side: CommandSide) -> InputEvent {
        .modifiersChanged(keyCode: side.keyCode, flags: [])
    }
}
