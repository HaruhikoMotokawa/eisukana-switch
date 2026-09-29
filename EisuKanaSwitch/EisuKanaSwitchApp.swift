import SwiftUI

@main
struct EisuKanaSwitchApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Text("⌘英")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    var body: some View {
        Button("about") {
            NSApp.orderFrontStandardAboutPanel(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
