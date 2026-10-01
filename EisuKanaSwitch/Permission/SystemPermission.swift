import AppKit
import CoreGraphics
import OSLog

/// 切り替えに要るシステムの許可（F-06）。
enum PermissionKind: String, CaseIterable, Sendable {
    /// 入力監視。⌘ キーが押されたことを知るため。
    case inputMonitoring
    /// アクセシビリティ（PostEvent）。「英数」「かな」キーを送るため（#32）。
    case postEvent
}

/// システム設定 > プライバシーとセキュリティ の許可の 1 つ（F-06）。
///
/// 状態を見るだけでなく、許可されたことを知らせるところまで持つ。許可はアプリからは
/// 変えられず、ユーザーがシステム設定で切り替えるのを待つしかないため（Spike #1）。
@MainActor
protocol SystemPermitting: AnyObject {
    /// 許可されているか。
    var isGranted: Bool { get }
    /// システムの確認ダイアログを出す。初回だけ出て、2 回目以降は何も起きない。
    func request()
    /// システム設定の該当ページを開く。
    func openSystemSettings()
    /// 許可状態が変わるまで見張る。見張っている間だけ通知するので、用が済んだら止める。
    func startWatching(onChange: @escaping (Bool) -> Void)
    /// 見張るのをやめる。
    func stopWatching()
}

/// `CGPreflightListenEventAccess` / `AXIsProcessTrusted` で状態を見る実装。
///
/// 許可されたことを知る手段は用意されていないので、見張っている間はタイマーで定期的に確認する（Spike #1）。
@MainActor
final class SystemPermission: SystemPermitting {
    /// システム設定で許可されたことに気づくまでの間隔。許可されるまで動き続けるので、
    /// 短くしすぎない。
    private static let pollingInterval: TimeInterval = 1

    let kind: PermissionKind
    private var timer: Timer?
    private var onChange: ((Bool) -> Void)?
    /// 直前に通知した状態。同じ値を何度も流さないために持つ。
    private var lastKnownState = false

    init(_ kind: PermissionKind) {
        self.kind = kind
    }

    var isGranted: Bool {
        switch kind {
        case .inputMonitoring: CGPreflightListenEventAccess()
        case .postEvent:
            // `CGPreflightPostEventAccess` はプロセスを起動したときの結果を返し続け、許可されても
            // 起動し直すまで true にならない。システム設定の「アクセシビリティ」は PostEvent も
            // 一緒に切り替えるので、その時々の状態を返す `AXIsProcessTrusted` で見る（#32）。
            AXIsProcessTrusted()
        }
    }

    func request() {
        let granted = switch kind {
        case .inputMonitoring: CGRequestListenEventAccess()
        case .postEvent: CGRequestPostEventAccess()
        }
        Logger.permission.notice("requested \(self.kind.rawValue, privacy: .public); granted=\(granted, privacy: .public)")
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(settingsURL)
    }

    func startWatching(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        lastKnownState = isGranted
        guard timer == nil else { return }
        // メニューを開いている間も run loop が回り続けるように common モードで動かす。
        let timer = Timer(timeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        // 遅れても困らない。まとめて起こしてもらえるように余裕を伝えておく（N-01）。
        timer.tolerance = Self.pollingInterval / 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Logger.permission.notice("watching \(self.kind.rawValue, privacy: .public); granted=\(self.lastKnownState, privacy: .public)")
    }

    func stopWatching() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        onChange = nil
        Logger.permission.notice("stopped watching \(self.kind.rawValue, privacy: .public)")
    }

    /// 変わったときだけ通知する。
    private func poll() {
        let granted = isGranted
        guard granted != lastKnownState else { return }
        lastKnownState = granted
        Logger.permission.notice("\(self.kind.rawValue, privacy: .public) changed; granted=\(granted, privacy: .public)")
        onChange?(granted)
    }

    /// プライバシーとセキュリティ の該当ページ。
    private var settingsURL: URL {
        switch kind {
        case .inputMonitoring:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        case .postEvent:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        }
    }
}
