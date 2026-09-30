import Foundation
import OSLog
import ServiceManagement

/// ログイン項目への登録先。`SMAppService` をこの裏に閉じ込める。
@MainActor
protocol LoginItemService: AnyObject {
    /// システム側の登録状態。
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    /// システム設定 > 一般 > ログイン項目を開く。
    func openSystemSettings()
}

/// アプリ本体をログイン項目にする実装。
@MainActor
final class MainAppLoginItemService: LoginItemService {
    private let service = SMAppService.mainApp

    var status: SMAppService.Status { service.status }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// ログイン時に自動起動するか（F-05）。
///
/// 状態は自前で保存せず、毎回システム側の登録状態から読む。ユーザーがシステム設定の
/// ログイン項目から外したり、許可を求められていたりすることがあり、保存した値だと
/// 実際とずれてしまうため。
@MainActor
@Observable
final class LaunchAtLogin {
    private let service: any LoginItemService

    /// 直近に読んだシステム側の登録状態。`refresh()` で読み直す。
    private(set) var status: SMAppService.Status

    init(service: any LoginItemService) {
        self.service = service
        status = service.status
    }

    /// 登録済みか。承認待ちも登録はされているので ON として見せる。
    /// OFF に見せると、ON にし直そうとして同じ承認待ちに戻るだけになる。
    var isOn: Bool {
        status == .enabled || status == .requiresApproval
    }

    /// 登録はされているが、システム設定のログイン項目で許可されるまで起動しない。
    var requiresApproval: Bool {
        status == .requiresApproval
    }

    /// システム設定で変えられていることがあるので、メニューを開くたびに読み直す。
    func refresh() {
        status = service.status
    }

    /// メニューからの ON/OFF の切り替え。
    func setOn(_ newValue: Bool) {
        guard newValue != isOn else { return }
        do {
            if newValue {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Logger.app.error("could not \(newValue ? "register" : "unregister", privacy: .public) the login item: \(error, privacy: .public)")
        }
        // 失敗しても、承認待ちになっても、実際の状態を見せる。
        refresh()
        Logger.app.notice("login item status=\(self.status.rawValue, privacy: .public)")
    }

    /// 承認待ちのときの「システム設定を開く」から呼ぶ。
    func openSystemSettings() {
        service.openSystemSettings()
    }
}
