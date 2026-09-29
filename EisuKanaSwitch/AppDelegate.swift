import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var keyMonitor = CommandKeyMonitor { [weak self] side in
        self?.handleSoloCommand(side)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        keyMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyMonitor.stop()
    }

    /// 入力ソースの切り替えは #4 で実装する。今はログに出すだけ。
    private func handleSoloCommand(_ side: CommandSide) {
        switch side {
        case .left:
            Logger.keyMonitor.notice("left command tapped (eisu)")
        case .right:
            Logger.keyMonitor.notice("right command tapped (kana)")
        }
    }
}
