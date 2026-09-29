import SwiftUI

@main
struct EisuKanaSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: appDelegate.controller)
        } label: {
            // 塗りつぶしなら有効、線画なら無効（F-04）。有効でも入力監視が未許可なら、
            // 切り替えが起きないことがアイコンでわかるようにする（F-06）。SF Symbols は
            // テンプレート画像として描かれるので、ライト / ダークどちらのメニューバーでもそのまま読める。
            Image(systemName: menuBarSymbol)
                .accessibilityLabel(Text(menuBarLabel))
        }
        .menuBarExtraStyle(.menu)

        Window("about_window_title", id: AboutWindow.id) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private var menuBarSymbol: String {
        guard appDelegate.controller.isEnabled else { return "command.circle" }
        return appDelegate.controller.hasInputMonitoringPermission
            ? "command.circle.fill"
            : "exclamationmark.triangle.fill"
    }

    private var menuBarLabel: LocalizedStringKey {
        guard appDelegate.controller.isEnabled else { return "menu_bar_disabled" }
        return appDelegate.controller.hasInputMonitoringPermission
            ? "menu_bar_enabled"
            : "menu_bar_no_permission"
    }
}
