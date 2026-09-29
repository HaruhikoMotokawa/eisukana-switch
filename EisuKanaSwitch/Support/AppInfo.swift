import Foundation

/// About で出す、アプリ自身の情報。
///
/// `Info.plist` の値は `GENERATE_INFOPLIST_FILE` でビルド設定から流し込まれるので、
/// バージョンはここで読み直す。文字列の組み立てだけは純粋関数にしてテストする。
enum AppInfo {
    /// 表示名。`CFBundleDisplayName`（無ければ `CFBundleName`）。
    static var name: String {
        bundleString("CFBundleDisplayName") ?? bundleString("CFBundleName") ?? "EisuKana Switch"
    }

    /// `CFBundleShortVersionString`。例: `0.1.0`
    static var shortVersion: String { bundleString("CFBundleShortVersionString") ?? "" }

    /// `CFBundleVersion`。例: `1`
    static var build: String { bundleString("CFBundleVersion") ?? "" }

    /// About に出すバージョン。例: `0.1.0 (1)`
    static var versionText: String { versionText(shortVersion: shortVersion, build: build) }

    /// ビルド番号が無い、または短縮版と同じなら、括弧は付けない。
    static func versionText(shortVersion: String, build: String) -> String {
        guard !build.isEmpty, build != shortVersion else { return shortVersion }
        return "\(shortVersion) (\(build))"
    }

    /// このアプリのリポジトリ。
    static let repositoryURL = URL(string: "https://github.com/HaruhikoMotokawa/eisukana-switch")!

    /// 着想を得た ⌘英かな（N-05）。
    static let cmdEikanaURL = URL(string: "https://github.com/iMasanari/cmd-eikana")!

    private static func bundleString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}
