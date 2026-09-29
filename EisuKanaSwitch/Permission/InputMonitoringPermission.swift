import AppKit
import CoreGraphics
import OSLog

/// 入力監視（システム設定 > プライバシーとセキュリティ > 入力監視）の許可（F-06）。
///
/// 状態を見るだけでなく、許可されたことを知らせるところまで持つ。許可はアプリからは
/// 変えられず、ユーザーがシステム設定で切り替えるのを待つしかないため（Spike #1）。
@MainActor
protocol InputMonitoringPermitting: AnyObject {
    /// 入力監視が許可されているか。
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

/// `CGPreflightListenEventAccess` で状態を見る実装。
///
/// 許可されても、監視を作り直すまでは反映されない。許可されたことを知る手段は
/// 用意されていないので、見張っている間はタイマーで定期的に確認する（Spike #1）。
@MainActor
final class InputMonitoringPermission: InputMonitoringPermitting {
    /// システム設定で許可されたことに気づくまでの間隔。許可されるまで動き続けるので、
    /// 短くしすぎない。
    private static let pollingInterval: TimeInterval = 1

    private var timer: Timer?
    private var onChange: ((Bool) -> Void)?
    /// 直前に通知した状態。同じ値を何度も流さないために持つ。
    private var lastKnownState = false

    var isGranted: Bool { CGPreflightListenEventAccess() }

    func request() {
        let granted = CGRequestListenEventAccess()
        Logger.permission.notice("requested input monitoring; granted=\(granted, privacy: .public)")
    }

    func openSystemSettings() {
        NSWorkspace.shared.open(Self.settingsURL)
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
        Logger.permission.notice("watching input monitoring; granted=\(self.lastKnownState, privacy: .public)")
    }

    func stopWatching() {
        guard timer != nil else { return }
        timer?.invalidate()
        timer = nil
        onChange = nil
        Logger.permission.notice("stopped watching input monitoring")
    }

    /// 変わったときだけ通知する。
    private func poll() {
        let granted = isGranted
        guard granted != lastKnownState else { return }
        lastKnownState = granted
        Logger.permission.notice("input monitoring changed; granted=\(granted, privacy: .public)")
        onChange?(granted)
    }

    /// プライバシーとセキュリティ > 入力監視。
    private static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    )!
}
