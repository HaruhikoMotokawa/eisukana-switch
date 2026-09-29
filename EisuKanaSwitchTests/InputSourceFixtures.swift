@testable import EisuKanaSwitch

/// 実機で `TISInputSource` から読み取った値をもとにした、入力ソースのテスト用データ。
enum InputSourceFixtures {
    // MARK: - キーボードレイアウト

    static let abc = InputSourceDescriptor(
        id: "com.apple.keylayout.ABC",
        bundleID: "com.apple.keyboardlayout.all",
        isKeyboardLayout: true,
        isASCIICapable: true,
        localizedName: "ABC"
    )

    static let dvorak = InputSourceDescriptor(
        id: "com.apple.keylayout.Dvorak",
        bundleID: "com.apple.keyboardlayout.all",
        isKeyboardLayout: true,
        isASCIICapable: true,
        localizedName: "Dvorak"
    )

    /// ASCII を打てないレイアウト。英数の候補にはならない。
    static let russian = InputSourceDescriptor(
        id: "com.apple.keylayout.Russian",
        bundleID: "com.apple.keyboardlayout.all",
        isKeyboardLayout: true,
        isASCIICapable: false,
        localizedName: "Russian"
    )

    // MARK: - ことえり（ローマ字入力）

    /// 最近の macOS で既定で有効になっている、唯一のことえりの入力ソース。
    static let kotoeriHiragana = InputSourceDescriptor(
        id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
        bundleID: "com.apple.inputmethod.Kotoeri.RomajiTyping",
        inputModeID: InputSourceDescriptor.InputModeID.japanese,
        localizedName: "ひらがな"
    )

    /// 既定では無効。ユーザーが自分で有効にしたときだけ一覧に入る。
    static let kotoeriRoman = InputSourceDescriptor(
        id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman",
        bundleID: "com.apple.inputmethod.Kotoeri.RomajiTyping",
        inputModeID: InputSourceDescriptor.InputModeID.roman,
        isASCIICapable: true,
        localizedName: "英字"
    )

    static let kotoeriKatakana = InputSourceDescriptor(
        id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese.Katakana",
        bundleID: "com.apple.inputmethod.Kotoeri.RomajiTyping",
        inputModeID: "com.apple.inputmethod.Japanese.Katakana",
        localizedName: "カタカナ"
    )

    // MARK: - Google 日本語入力

    static let googleHiragana = InputSourceDescriptor(
        id: "com.google.inputmethod.Japanese.base",
        bundleID: "com.google.inputmethod.Japanese",
        inputModeID: InputSourceDescriptor.InputModeID.japanese,
        localizedName: "ひらがな"
    )

    static let googleRoman = InputSourceDescriptor(
        id: "com.google.inputmethod.Japanese.Roman",
        bundleID: "com.google.inputmethod.Japanese",
        inputModeID: InputSourceDescriptor.InputModeID.roman,
        isASCIICapable: true,
        localizedName: "英数"
    )

    // MARK: - ATOK

    static let atokHiragana = InputSourceDescriptor(
        id: "com.justsystems.inputmethod.atok34.Japanese",
        bundleID: "com.justsystems.inputmethod.atok34",
        inputModeID: InputSourceDescriptor.InputModeID.japanese,
        localizedName: "ひらがな"
    )

    static let atokRoman = InputSourceDescriptor(
        id: "com.justsystems.inputmethod.atok34.Roman",
        bundleID: "com.justsystems.inputmethod.atok34",
        inputModeID: InputSourceDescriptor.InputModeID.roman,
        isASCIICapable: true,
        localizedName: "英数"
    )

    // MARK: - よくある構成

    /// このプロジェクトの検証環境。ABC とことえりのひらがなだけが有効。
    static let kotoeriOnly = [abc, kotoeriHiragana]
    /// Google 日本語入力の英数モードも有効にしている構成。
    static let googleWithRoman = [abc, googleHiragana, googleRoman]
    /// ABC を無効にして IME だけを使っている構成。英数の候補が無い。
    static let japaneseOnly = [kotoeriHiragana]
}
