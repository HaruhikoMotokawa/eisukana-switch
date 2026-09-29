import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// ⌘ の監視と入力ソースの切り替えをまとめて持つ。`MenuBarExtra` がアイコンの
    /// 見た目を決めるのに読むので、`applicationDidFinishLaunching` より先に作られる。
    lazy var controller = SwitchingController(
        monitor: CommandKeyMonitor(),
        switcher: InputSourceSwitcher(repository: CarbonInputSourceRepository()),
        store: UserDefaultsEnabledStateStore(),
        permission: InputMonitoringPermission()
    )

    private let permissionWindow = PermissionWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        // 有効なのに未許可だと、何も起きないアプリに見えてしまう。理由と行き先を出す（F-06）。
        if controller.isEnabled, !controller.hasInputMonitoringPermission {
            permissionWindow.show(controller: controller)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}
