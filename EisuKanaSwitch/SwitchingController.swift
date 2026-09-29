import Foundation
import OSLog

/// ⌘ の検出（#3）と入力ソースの切り替え（#4）を繋ぎ、有効/無効を持つ（F-04）。
///
/// 無効のときはイベントタップごと止める。イベントを受け取ってから捨てるのではなく
/// タップを落とすので、無効の間はキー入力が一切アプリに届かないし、CPU も使わない（N-01 / N-02）。
@MainActor
@Observable
final class SwitchingController {
    private let monitor: any CommandKeyMonitoring
    private let switcher: any InputSourceSwitching
    private let store: any EnabledStateStore

    /// 切り替えが有効か。変更は `setEnabled(_:)` から行う。
    private(set) var isEnabled: Bool

    init(
        monitor: any CommandKeyMonitoring,
        switcher: any InputSourceSwitching,
        store: any EnabledStateStore
    ) {
        self.monitor = monitor
        self.switcher = switcher
        self.store = store
        isEnabled = store.isEnabled
        monitor.onSoloCommand = { [weak self] side in
            self?.handleSoloCommand(side)
        }
    }

    /// 起動時に呼ぶ。前回終了時に有効だったときだけ監視を始める。
    ///
    /// 入力監視が未許可だと `start()` は false を返すが、ここでは何もしない。
    /// 状態の表示とシステム設定への案内は #6（F-06）で扱う。
    func start() {
        guard isEnabled else {
            Logger.app.notice("launched disabled; not starting the monitor")
            return
        }
        monitor.start()
    }

    /// 終了時に呼ぶ。
    func stop() {
        monitor.stop()
    }

    /// メニューからの有効/無効の切り替え。設定は即座に保存する。
    func setEnabled(_ newValue: Bool) {
        guard newValue != isEnabled else { return }
        isEnabled = newValue
        store.isEnabled = newValue
        if newValue {
            monitor.start()
        } else {
            monitor.stop()
        }
        Logger.app.notice("switching \(newValue ? "enabled" : "disabled", privacy: .public)")
    }

    /// 無効のときはタップを止めてあるので普通は呼ばれないが、止める前に届いた
    /// イベントで切り替わってしまわないように、ここでも見ておく。
    private func handleSoloCommand(_ side: CommandSide) {
        guard isEnabled else { return }
        switcher.activate(for: side)
    }
}
