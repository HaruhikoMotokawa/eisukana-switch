import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// ⌘ の監視と入力ソースの切り替えをまとめて持つ。`MenuBarExtra` がアイコンの
    /// 見た目を決めるのに読むので、`applicationDidFinishLaunching` より先に作られる。
    lazy var controller = SwitchingController(
        monitor: CommandKeyMonitor(),
        switcher: JISKeySwitcher(),
        store: UserDefaultsEnabledStateStore(),
        inputMonitoring: SystemPermission(.inputMonitoring),
        postEvent: SystemPermission(.postEvent)
    )

    /// ログイン時の自動起動（F-05）。メニューが ON/OFF の表示に読む。
    let launchAtLogin = LaunchAtLogin(service: MainAppLoginItemService())

    private let permissionWindow = PermissionWindowController()
    private var menuTrackingObserver: (any NSObjectProtocol)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ユニットテストはこのアプリをホストにして動くので、アプリ本体も起動する。ここで許可を求めると、
        // ad-hoc 署名のテスト用ビルドが TCC に登録され、正式なビルドの許可が効かなくなる（#32）。
        guard !Self.isRunningUnitTests else { return }
        controller.start()
        // ログイン項目はシステム設定でも変えられるので、メニューを開くたびに読み直す。
        menuTrackingObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.launchAtLogin.refresh()
            }
        }
        // 有効なのに未許可だと、何も起きないアプリに見えてしまう。理由と行き先を出す（F-06）。
        if controller.isEnabled, !controller.hasAllPermissions {
            permissionWindow.show(controller: controller)
        }
    }

    /// XCTest（Swift Testing も含む）のホストとして起動されたか。
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}
