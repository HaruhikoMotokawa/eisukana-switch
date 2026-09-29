import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// ⌘ の監視と入力ソースの切り替えをまとめて持つ。`MenuBarExtra` がアイコンの
    /// 見た目を決めるのに読むので、`applicationDidFinishLaunching` より先に作られる。
    lazy var controller = SwitchingController(
        monitor: CommandKeyMonitor(),
        switcher: InputSourceSwitcher(repository: CarbonInputSourceRepository()),
        store: UserDefaultsEnabledStateStore()
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}
