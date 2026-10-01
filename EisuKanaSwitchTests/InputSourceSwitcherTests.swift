import Carbon.HIToolbox
import Testing
@testable import EisuKanaSwitch

@Suite("InputSourceTarget")
struct InputSourceTargetTests {
    @Test("左 ⌘ で英数、右 ⌘ でかなへ切り替える")
    func assignsTargetToEachSide() {
        #expect(CommandSide.left.inputSourceTarget == .eisu)
        #expect(CommandSide.right.inputSourceTarget == .kana)
    }

    @Test("英数は「英数」キー、かなは「かな」キーを送る")
    func sendsJISKeys() {
        #expect(InputSourceTarget.eisu.jisKeyCode == CGKeyCode(kVK_JIS_Eisu))
        #expect(InputSourceTarget.kana.jisKeyCode == CGKeyCode(kVK_JIS_Kana))
    }
}
