import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "io.github.haruhikomotokawa.EisuKanaSwitch"

    static let keyMonitor = Logger(subsystem: subsystem, category: "KeyMonitor")
    static let app = Logger(subsystem: subsystem, category: "App")
}
