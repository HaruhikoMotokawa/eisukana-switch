import Foundation

/// 有効/無効の保存先。`UserDefaults` をこの裏に閉じ込める。
@MainActor
protocol EnabledStateStore: AnyObject {
    var isEnabled: Bool { get set }
}

/// `UserDefaults` に保存する実装。
///
/// 保存されていなければ有効として扱う。初回起動でいきなり無効だと、
/// 何も起きないアプリに見えてしまうため。
@MainActor
final class UserDefaultsEnabledStateStore: EnabledStateStore {
    /// 既存の設定を読めなくするので、あとから変えない。
    private static let key = "isEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.object(forKey: Self.key) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}
