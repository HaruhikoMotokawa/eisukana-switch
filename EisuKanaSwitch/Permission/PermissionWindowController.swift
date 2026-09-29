import AppKit
import SwiftUI

/// 入力監視の案内ウインドウを持つ（F-06）。
///
/// About と違って `Window` シーンにしていないのは、起動直後に AppDelegate から出したいため。
/// `openWindow` は View の中でしか読めず、シーンを起動時に開く `defaultLaunchBehavior` は
/// macOS 15 以降で、対応 OS（macOS 14）では使えない。
@MainActor
final class PermissionWindowController {
    private var window: NSWindow?

    /// 案内を出す。すでに出ていれば前面に移動するだけ。
    func show(controller: SwitchingController) {
        let window = window ?? makeWindow(controller: controller)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        // LSUIElement なのでアクティブなアプリにならない。自分で前面に出さないと後ろに開く。
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow(controller: SwitchingController) -> NSWindow {
        let view = PermissionView(controller: controller) { [weak self] in
            self?.window?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(localized: "permission_window_title")
        window.styleMask = [.titled, .closable]
        // 閉じても作り直さずに使い回す。
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
