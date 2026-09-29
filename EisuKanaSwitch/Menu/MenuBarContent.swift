import AppKit
import SwiftUI

/// メニューバーのアイコンをクリックしたときに出るメニュー（F-04 / F-06）。
struct MenuBarContent: View {
    let controller: SwitchingController

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // 有効なのに未許可だと切り替えが起きないので、理由と行き先を一番上に出す（F-06）。
        // 無効のときは元々切り替えないので、許可の話は出さない。
        if controller.isEnabled, !controller.hasInputMonitoringPermission {
            Text("permission_menu_status")
            Button("permission_open_settings") {
                controller.openInputMonitoringSettings()
            }
            Divider()
        }
        Toggle("enabled", isOn: Binding(
            get: { controller.isEnabled },
            set: { controller.setEnabled($0) }
        ))
        Divider()
        Button("about") {
            openAbout()
        }
        Divider()
        Button("quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// LSUIElement なのでアクティブなアプリにならない。自分で前面に出さないと、
    /// About が他のウインドウの後ろに開いてしまう。
    private func openAbout() {
        openWindow(id: AboutWindow.id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
