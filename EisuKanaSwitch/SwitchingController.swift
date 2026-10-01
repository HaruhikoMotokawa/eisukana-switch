import Foundation
import OSLog

/// ⌘ の検出（#3）と入力ソースの切り替え（#4 / #32）を繋ぎ、有効/無効（F-04）と
/// 入力監視・アクセシビリティの許可状態（F-06）を持つ。
///
/// 無効のときはイベントタップごと止める。イベントを受け取ってから捨てるのではなく
/// タップを落とすので、無効の間はキー入力が一切アプリに届かないし、CPU も使わない（N-01 / N-02）。
@MainActor
@Observable
final class SwitchingController {
    private let monitor: any CommandKeyMonitoring
    private let switcher: any InputSourceSwitching
    private let store: any EnabledStateStore
    private let inputMonitoring: any SystemPermitting
    private let postEvent: any SystemPermitting

    /// 切り替えが有効か。変更は `setEnabled(_:)` から行う。
    private(set) var isEnabled: Bool

    /// 入力監視が許可されているか。未許可ならメニューと案内で知らせる（F-06）。
    private(set) var hasInputMonitoringPermission: Bool

    /// アクセシビリティ（PostEvent）が許可されているか。未許可だとキーを送っても捨てられるので、
    /// 入力監視と同じく、許可されるまで監視を始めない（#32）。
    private(set) var hasPostEventPermission: Bool

    /// 監視が動いているか。許可されていても、タップを作れずに動いていないことがある（#24）。
    private(set) var isMonitoring = false

    /// メニューバーとメニューに出す状態。
    enum Status: Equatable {
        /// 無効にされている。
        case disabled
        /// 有効だが、入力監視かアクセシビリティが未許可で、許可を待っている。
        case needsPermission
        /// 有効で許可もされているが、監視を始められなかった。
        case failedToStart
        /// 切り替えが動いている。
        case running
    }

    var status: Status {
        guard isEnabled else { return .disabled }
        guard hasAllPermissions else { return .needsPermission }
        return isMonitoring ? .running : .failedToStart
    }

    /// 切り替えに要る許可が全部そろっているか。
    var hasAllPermissions: Bool {
        hasInputMonitoringPermission && hasPostEventPermission
    }

    /// その許可がされているか。
    func isGranted(_ kind: PermissionKind) -> Bool {
        switch kind {
        case .inputMonitoring: hasInputMonitoringPermission
        case .postEvent: hasPostEventPermission
        }
    }

    /// まだ許可されていないもの。案内やメニューに並べる順で返す。
    var missingPermissions: [PermissionKind] {
        PermissionKind.allCases.filter { !isGranted($0) }
    }

    init(
        monitor: any CommandKeyMonitoring,
        switcher: any InputSourceSwitching,
        store: any EnabledStateStore,
        inputMonitoring: any SystemPermitting,
        postEvent: any SystemPermitting
    ) {
        self.monitor = monitor
        self.switcher = switcher
        self.store = store
        self.inputMonitoring = inputMonitoring
        self.postEvent = postEvent
        isEnabled = store.isEnabled
        hasInputMonitoringPermission = inputMonitoring.isGranted
        hasPostEventPermission = postEvent.isGranted
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
        stopWatchingPermissions()
        stopMonitor()
    }

    /// メニューからの有効/無効の切り替え。設定は即座に保存する。
    func setEnabled(_ newValue: Bool) {
        guard newValue != isEnabled else { return }
        isEnabled = newValue
        store.isEnabled = newValue
        if newValue {
            startMonitoring(requestingPermission: true)
        } else {
            stopWatchingPermissions()
            stopMonitor()
        }
        Logger.app.notice("switching \(newValue ? "enabled" : "disabled", privacy: .public)")
    }

    /// メニューや案内の「システム設定を開く」から呼ぶ（F-06）。
    ///
    /// 見張っていない間に許可されていることがあるので、開く前に状態を見直す。
    /// まだ未許可なら、許可されたら再起動なしで始められるように見張り始める。
    func openSystemSettings(for kind: PermissionKind) {
        permission(kind).openSystemSettings()
        guard isEnabled else {
            // 無効なら監視も待機も要らない。表示だけ合わせておく。
            refreshPermissions()
            return
        }
        startMonitoring(requestingPermission: false)
    }

    /// メニューの「もう一度試す」から呼ぶ。監視を始められなかったときの再試行（#24）。
    ///
    /// 始められないのはリソース不足などの一時的な理由なので、自動で繰り返さず、
    /// ユーザーが試し直せるようにしておく。試す間に許可が外れていることもあるので、許可から見直す。
    func retryMonitoring() {
        guard status == .failedToStart else { return }
        Logger.app.notice("retrying to start the monitor")
        startMonitoring(requestingPermission: false)
    }

    /// 監視を始める。どちらかが未許可なら始めず、許可されるのを待つ。
    ///
    /// 入力監視が未許可でも `CGEvent.tapCreate` は成功してしまい、イベントが届かないまま
    /// `tapDisabledByUserInput` が繰り返される。アクセシビリティが未許可だと、送ったキーが
    /// エラーも出ずに捨てられる。どちらも、権限を確認してから始める（Spike #1）。
    ///
    /// - Parameter requestingPermission: 未許可のときにシステムの確認ダイアログを出すか。
    ///   初回起動でこれが出ることで、システム設定の一覧にアプリが並ぶ。
    private func startMonitoring(requestingPermission: Bool) {
        refreshPermissions()
        guard hasAllPermissions else {
            let missing = missingPermissions.map(\.rawValue).joined(separator: ",")
            Logger.app.notice("not granted: \(missing, privacy: .public); waiting for it")
            if requestingPermission {
                missingPermissions.forEach { permission($0).request() }
            }
            watchPermissions()
            return
        }
        stopWatchingPermissions()
        startMonitor()
    }

    /// 監視を始める。許可されているのに始められないのは普通は起きないが、起きると
    /// 何も反応しないまま「有効」に見えてしまうので、`isMonitoring` に残して表示で知らせる（#24）。
    private func startMonitor() {
        isMonitoring = monitor.start()
        if !isMonitoring {
            Logger.app.error("could not start the monitor although input monitoring is granted")
        }
    }

    private func stopMonitor() {
        monitor.stop()
        isMonitoring = false
    }

    private func permission(_ kind: PermissionKind) -> any SystemPermitting {
        switch kind {
        case .inputMonitoring: inputMonitoring
        case .postEvent: postEvent
        }
    }

    private func refreshPermissions() {
        hasInputMonitoringPermission = inputMonitoring.isGranted
        hasPostEventPermission = postEvent.isGranted
    }

    /// 許可されるのを待つ。全部そろったら、再起動せずにそのまま監視を始める（F-06）。
    ///
    /// 許可済みのものも見張る。待っている間に外されても、表示が古いままにならないように。
    private func watchPermissions() {
        for kind in PermissionKind.allCases {
            permission(kind).startWatching { [weak self] granted in
                self?.handlePermissionChange(kind, granted: granted)
            }
        }
    }

    private func stopWatchingPermissions() {
        PermissionKind.allCases.forEach { permission($0).stopWatching() }
    }

    private func handlePermissionChange(_ kind: PermissionKind, granted: Bool) {
        switch kind {
        case .inputMonitoring: hasInputMonitoringPermission = granted
        case .postEvent: hasPostEventPermission = granted
        }
        guard hasAllPermissions else { return }
        stopWatchingPermissions()
        // 待っている間に無効にされていることがあるので、ここでも見ておく。
        guard isEnabled else { return }
        Logger.app.notice("all permissions granted; starting the monitor")
        startMonitor()
    }

    /// 監視中に入力監視の許可が外れて、監視が止まったとき。また案内を出し、許可し直されるのを待つ。
    private func handlePermissionLost() {
        Logger.app.error("input monitoring was revoked; the monitor has stopped")
        hasInputMonitoringPermission = false
        isMonitoring = false
        guard isEnabled else { return }
        watchPermissions()
    }

    /// 監視中にアクセシビリティの許可が外れていたとき。キーを送っても捨てられるだけなので、
    /// 入力監視が外れたときと同じく監視を止めて、許可し直されるのを待つ。
    private func handlePostEventPermissionLost() {
        Logger.app.error("accessibility was revoked; stopping the monitor")
        hasPostEventPermission = false
        stopMonitor()
        guard isEnabled else { return }
        watchPermissions()
    }

    /// 無効のときはタップを止めてあるので普通は呼ばれないが、止める前に届いた
    /// イベントで切り替わってしまわないように、ここでも見ておく。
    ///
    /// アクセシビリティは、外されてもタップのように知らせてくれないので、送る前に毎回確かめる。
    /// ⌘ の単独押下のときにしか呼ばれないので、毎回でも負担にならない（N-01）。
    private func handleSoloCommand(_ side: CommandSide) {
        guard isEnabled else { return }
        guard postEvent.isGranted else {
            handlePostEventPermissionLost()
            return
        }
        switcher.activate(for: side)
    }
}
