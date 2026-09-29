import Foundation

/// `TISInputSource` から、切り替え先を決めるのに必要なプロパティだけを写した値型。
///
/// Carbon の型をロジックから切り離すために挟んでいる。おかげで、切り替え先の判定は
/// 実機にどんな入力ソースが入っているかに関係なくユニットテストできる。
struct InputSourceDescriptor: Equatable, Hashable, Sendable {
    /// `kTISPropertyInputSourceID`。例: `com.apple.keylayout.ABC`
    let id: String
    /// `kTISPropertyBundleID`。同じ IME に属する入力モードを見つけるのに使う。
    let bundleID: String?
    /// `kTISPropertyInputModeID`。入力モードを持たないキーボードレイアウトでは nil。
    let inputModeID: String?
    /// `kTISPropertyInputSourceType` が `kTISTypeKeyboardLayout` か。
    let isKeyboardLayout: Bool
    /// `kTISPropertyInputSourceIsASCIICapable`。
    let isASCIICapable: Bool
    /// `kTISPropertyLocalizedName`。ログと、将来のメニュー表示用。
    let localizedName: String?

    init(
        id: String,
        bundleID: String? = nil,
        inputModeID: String? = nil,
        isKeyboardLayout: Bool = false,
        isASCIICapable: Bool = false,
        localizedName: String? = nil
    ) {
        self.id = id
        self.bundleID = bundleID
        self.inputModeID = inputModeID
        self.isKeyboardLayout = isKeyboardLayout
        self.isASCIICapable = isASCIICapable
        self.localizedName = localizedName
    }
}

extension InputSourceDescriptor {
    /// `kTISPropertyInputModeID` に入る値のうち、この機能で見るもの。
    /// ことえり・Google 日本語入力・ATOK のいずれも、この値を返す。
    enum InputModeID {
        /// IME の英数モード。
        static let roman = "com.apple.inputmethod.Roman"
        /// IME のひらがなモード。カタカナ・全角英数・半角カナは別の値になる。
        static let japanese = "com.apple.inputmethod.Japanese"
    }

    /// 英数モードの入力ソースか。
    ///
    /// 最近の macOS では、ことえりの英数モードは入力ソースとして有効になっていないので、
    /// これに当たるのは Google 日本語入力や ATOK の「英数」を有効にしている場合が中心。
    var isRomanMode: Bool {
        if inputModeID == InputModeID.roman { return true }
        // Spike #1 で確認した経路。ベンダー独自の入力モードに対する保険として残す。
        return inputModeID == nil ? false : id.hasSuffix(".Roman")
    }

    /// ひらがなモードの入力ソースか。
    var isKanaMode: Bool {
        inputModeID == InputModeID.japanese
    }

    /// ABC や US のような、そのまま英数を打てるキーボードレイアウトか。
    var isLatinKeyboardLayout: Bool {
        isKeyboardLayout && isASCIICapable
    }

    /// すでに英数が打てる状態か。ここが true なら左 ⌘ は何もしない。
    var isEisu: Bool {
        isRomanMode || isLatinKeyboardLayout
    }
}
