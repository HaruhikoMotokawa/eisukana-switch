import AppKit
import SwiftUI

/// メニューバーのアイコンをクリックしたときに出るメニュー（F-04）。
struct MenuBarContent: View {
    let controller: SwitchingController

    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
