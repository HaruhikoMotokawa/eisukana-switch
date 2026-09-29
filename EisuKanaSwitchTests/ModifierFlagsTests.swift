import CoreGraphics
import Testing
@testable import EisuKanaSwitch

@Suite("CGEventFlags から判定用の修飾キーへの変換")
struct ModifierFlagsTests {
    @Test("判定に使う修飾キーを読み取る", arguments: [
        (CGEventFlags.maskCommand, ModifierFlags.command),
        (.maskShift, .shift),
        (.maskControl, .control),
        (.maskAlternate, .option),
        (.maskSecondaryFn, .fn),
    ])
    func readsTrackedModifiers(cgFlags: CGEventFlags, expected: ModifierFlags) {
        #expect(ModifierFlags(cgFlags) == expected)
    }

    @Test("Caps Lock は無視する")
    func ignoresCapsLock() {
        // ロック状態であって同時押しではない。他の修飾キーとして扱うと、
        // Caps Lock が ON の間ずっと切り替わらなくなってしまう。
        #expect(ModifierFlags(.maskAlphaShift) == [])
        #expect(ModifierFlags([.maskCommand, .maskAlphaShift]) == .command)
    }

    @Test("左右を区別するビットは無視する")
    func ignoresDeviceDependentBits() {
        // flagsChanged の flags には NX_DEVICELCMDKEYMASK などのビットも立つ。左右は keyCode で見る。
        let leftCommand = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x0000_0008)
        #expect(ModifierFlags(leftCommand) == .command)
    }

    @Test("修飾キーを押していなければ空になる")
    func emptyWhenNoModifiers() {
        #expect(ModifierFlags([]) == [])
        #expect(ModifierFlags(.maskNonCoalesced) == [])
    }

    @Test("複数の修飾キーを同時に読み取る")
    func readsMultipleModifiers() {
        #expect(ModifierFlags([.maskCommand, .maskShift]) == [.command, .shift])
    }
}

@Suite("keyCode から左右の判定")
struct CommandSideTests {
    @Test("左 ⌘ は 55、右 ⌘ は 54")
    func knownKeyCodes() {
        #expect(CommandSide(keyCode: 55) == .left)
        #expect(CommandSide(keyCode: 54) == .right)
    }

    @Test("⌘ 以外の keyCode では nil", arguments: [56, 58, 59, 63, 0] as [Int64])
    func otherKeyCodes(keyCode: Int64) {
        #expect(CommandSide(keyCode: keyCode) == nil)
    }
}
