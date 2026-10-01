import SwiftUI

@main
struct EisuKanaSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: appDelegate.controller, launchAtLogin: appDelegate.launchAtLogin)
        } label: {
            // 塗りつぶしなら有効、線画なら無効（F-04）。有効でも入力監視が未許可だったり、
            // 監視を始められなかったりしたら、切り替えが起きないことがアイコンでわかるようにする（F-06 / #24）。SF Symbols は
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
        switch appDelegate.controller.status {
        case .disabled: "command.circle"
        case .running: "command.circle.fill"
        case .needsPermission, .failedToStart: "exclamationmark.triangle.fill"
        }
    }

    private var menuBarLabel: LocalizedStringKey {
        switch appDelegate.controller.status {
        case .disabled: "menu_bar_disabled"
        case .running: "menu_bar_enabled"
        case .needsPermission: "menu_bar_no_permission"
        case .failedToStart: "menu_bar_monitor_failed"
        }
    }
}
