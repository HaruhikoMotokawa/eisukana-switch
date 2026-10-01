import SwiftUI

/// 入力監視・アクセシビリティが未許可のときに出す案内（F-06）。
///
/// 許可されたらその場で表示を切り替える。再起動しなくても切り替えが始まることを、
/// ここで見せて伝える。
struct PermissionView: View {
    let controller: SwitchingController
    /// 「閉じる」で呼ぶ。ウインドウを持っているのは `PermissionWindowController`。
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isWorking ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(isWorking ? Color.green : Color.orange)
                .accessibilityHidden(true)

            Text(controller.hasAllPermissions ? "permission_granted_title" : "permission_title")
                .font(.title3.weight(.semibold))

            if controller.status == .failedToStart {
                // 許可はされたが監視を始められなかった。「開始しました」とは言えない（#24）。
                Text("monitor_failed_body")
            } else if controller.hasAllPermissions {
                Text("permission_granted_body")
            } else {
                Text("permission_body")
                VStack(spacing: 8) {
                    ForEach(PermissionKind.allCases, id: \.self) { kind in
                        PermissionRow(kind: kind, isGranted: controller.isGranted(kind)) {
                            controller.openSystemSettings(for: kind)
                        }
                    }
                }
                Text("permission_privacy_note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if controller.status == .failedToStart {
                    Button("permission_close", action: onClose)
                    Button("monitor_failed_retry") {
                        controller.retryMonitoring()
                    }
                    .keyboardShortcut(.defaultAction)
                } else if controller.hasAllPermissions {
                    Button("permission_close", action: onClose)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("permission_later", action: onClose)
                }
            }
            .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        // 日本語と英語で行数が変わるので、高さは中身に合わせる。
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(width: 400)
    }

    /// 許可されて、切り替えが動き出せたか。許可されても始められなかったときは警告のままにする。
    private var isWorking: Bool {
        controller.hasAllPermissions && controller.status != .failedToStart
    }
}

/// 許可 1 つ分の行。許可済みならそう示し、未許可ならシステム設定へ案内する。
private struct PermissionRow: View {
    let kind: PermissionKind
    let isGranted: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .fontWeight(.medium)
                Text(kind.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            Spacer()
            if isGranted {
                Text("permission_allowed")
                    .foregroundStyle(.secondary)
            } else {
                Button("permission_open_settings", action: openSettings)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

extension PermissionKind {
    /// システム設定での名前。
    var title: LocalizedStringKey {
        switch self {
        case .inputMonitoring: "permission_input_monitoring"
        case .postEvent: "permission_accessibility"
        }
    }

    /// 何のために要るか。
    var reason: LocalizedStringKey {
        switch self {
        case .inputMonitoring: "permission_input_monitoring_reason"
        case .postEvent: "permission_accessibility_reason"
        }
    }

    /// 未許可のときにメニューに出す一行。
    var menuStatus: LocalizedStringKey {
        switch self {
        case .inputMonitoring: "input_monitoring_menu_status"
        case .postEvent: "accessibility_menu_status"
        }
    }

    /// メニューからシステム設定を開く項目。2 つ並ぶことがあるので、どちらを開くか書いておく。
    var openSettingsTitle: LocalizedStringKey {
        switch self {
        case .inputMonitoring: "input_monitoring_open_settings"
        case .postEvent: "accessibility_open_settings"
        }
    }
}
