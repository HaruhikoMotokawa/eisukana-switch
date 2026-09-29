import Foundation
import OSLog

/// ⌘ の検出（#3）と入力ソースの切り替え（#4）を繋ぎ、有効/無効（F-04）と
/// 入力監視の許可状態（F-06）を持つ。
///
/// 無効のときはイベントタップごと止める。イベントを受け取ってから捨てるのではなく
/// タップを落とすので、無効の間はキー入力が一切アプリに届かないし、CPU も使わない（N-01 / N-02）。
@MainActor
@Observable
final class SwitchingController {
    private let monitor: any CommandKeyMonitoring
    private let switcher: any InputSourceSwitching
    private let store: any EnabledStateStore
    private let permission: any InputMonitoringPermitting

    /// 切り替えが有効か。変更は `setEnabled(_:)` から行う。
    private(set) var isEnabled: Bool

    /// 入力監視が許可されているか。未許可ならメニューと案内で知らせる（F-06）。
    private(set) var hasInputMonitoringPermission: Bool

    init(
        monitor: any CommandKeyMonitoring,
        switcher: any InputSourceSwitching,
        store: any EnabledStateStore,
        permission: any InputMonitoringPermitting
    ) {
        self.monitor = monitor
        self.switcher = switcher
        self.store = store
        self.permission = permission
        isEnabled = store.isEnabled
        hasInputMonitoringPermission = permission.isGranted
        monitor.onSoloCommand = { [weak self] side in
            self?.handleSoloCommand(side)
        }
        monitor.onPermissionLost = { [weak self] in
            self?.handlePermissionLost()
        }
    }

    /// 起動時に呼ぶ。前回終了時に有効だったときだけ監視を始める。
    func start() {
        guard isEnabled else {
            Logger.app.notice("launched disabled; not starting the monitor")
            return
        }
        startMonitoring(requestingPermission: true)
    }

    /// 終了時に呼ぶ。
    func stop() {
        permission.stopWatching()
        monitor.stop()
    }

    /// メニューからの有効/無効の切り替え。設定は即座に保存する。
    func setEnabled(_ newValue: Bool) {
        guard newValue != isEnabled else { return }
        isEnabled = newValue
        store.isEnabled = newValue
        if newValue {
            startMonitoring(requestingPermission: true)
        } else {
            permission.stopWatching()
            monitor.stop()
        }
        Logger.app.notice("switching \(newValue ? "enabled" : "disabled", privacy: .public)")
    }

    /// メニューや案内の「システム設定を開く」から呼ぶ（F-06）。
    ///
    /// 見張っていない間に許可されていることがあるので、開く前に状態を見直す。
    /// まだ未許可なら、許可されたら再起動なしで始められるように見張り始める。
    func openInputMonitoringSettings() {
        permission.openSystemSettings()
        guard isEnabled else {
            // 無効なら監視も待機も要らない。表示だけ合わせておく。
            hasInputMonitoringPermission = permission.isGranted
            return
        }
        startMonitoring(requestingPermission: false)
    }

    /// 監視を始める。未許可なら始めず、許可されるのを待つ。
    ///
    /// 未許可でも `CGEvent.tapCreate` は成功してしまい、イベントが届かないまま
    /// `tapDisabledByUserInput` が繰り返されるので、権限を確認してから始める（Spike #1）。
    ///
    /// - Parameter requestingPermission: 未許可のときにシステムの確認ダイアログを出すか。
    ///   初回起動でこれが出ることで、システム設定の一覧にアプリが並ぶ。
    private func startMonitoring(requestingPermission: Bool) {
        hasInputMonitoringPermission = permission.isGranted
        guard hasInputMonitoringPermission else {
            Logger.app.notice("input monitoring is not granted; waiting for it")
            if requestingPermission {
                permission.request()
            }
            watchPermission()
            return
        }
        permission.stopWatching()
        startMonitor()
    }

    /// 監視を始める。許可されているのに始められないのは普通は起きないが、起きると
    /// 何も反応しないまま「有効」に見えてしまうので、ログには残す。
    private func startMonitor() {
        if !monitor.start() {
            Logger.app.error("could not start the monitor although input monitoring is granted")
        }
    }

    /// 許可されるのを待つ。許可されたら、再起動せずにそのまま監視を始める（F-06）。
    private func watchPermission() {
        permission.startWatching { [weak self] granted in
            self?.handlePermissionChange(granted)
        }
    }

    private func handlePermissionChange(_ granted: Bool) {
        hasInputMonitoringPermission = granted
        guard granted else { return }
        permission.stopWatching()
        // 待っている間に無効にされていることがあるので、ここでも見ておく。
        guard isEnabled else { return }
        Logger.app.notice("input monitoring granted; starting the monitor")
        startMonitor()
    }

    /// 監視中に許可が外れて、監視が止まったとき。また案内を出し、許可し直されるのを待つ。
    private func handlePermissionLost() {
        Logger.app.error("input monitoring was revoked; the monitor has stopped")
        hasInputMonitoringPermission = false
        guard isEnabled else { return }
        watchPermission()
    }

    /// 無効のときはタップを止めてあるので普通は呼ばれないが、止める前に届いた
    /// イベントで切り替わってしまわないように、ここでも見ておく。
    private func handleSoloCommand(_ side: CommandSide) {
        guard isEnabled else { return }
        switcher.activate(for: side)
    }
}
