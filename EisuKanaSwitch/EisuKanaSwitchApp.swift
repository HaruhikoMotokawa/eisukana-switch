import SwiftUI

@main
struct EisuKanaSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: appDelegate.controller)
        } label: {
            // 塗りつぶしなら有効、線画なら無効（F-04）。SF Symbols はテンプレート画像として
            // 描かれるので、ライト / ダークどちらのメニューバーでもそのまま読める。
            Image(systemName: appDelegate.controller.isEnabled ? "command.circle.fill" : "command.circle")
                .accessibilityLabel(Text(menuBarLabel))
        }
        .menuBarExtraStyle(.menu)

        Window("about_window_title", id: AboutWindow.id) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private var menuBarLabel: LocalizedStringKey {
        appDelegate.controller.isEnabled ? "menu_bar_enabled" : "menu_bar_disabled"
    }
}
