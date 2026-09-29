import SwiftUI

/// 入力監視が未許可のときに出す案内（F-06）。
///
/// 許可されたらその場で表示を切り替える。再起動しなくても切り替えが始まることを、
/// ここで見せて伝える。
struct PermissionView: View {
    let controller: SwitchingController
    /// 「閉じる」で呼ぶ。ウインドウを持っているのは `PermissionWindowController`。
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: controller.hasInputMonitoringPermission
                ? "checkmark.circle.fill"
                : "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(controller.hasInputMonitoringPermission ? Color.green : Color.orange)
                .accessibilityHidden(true)

            Text(controller.hasInputMonitoringPermission ? "permission_granted_title" : "permission_title")
                .font(.title3.weight(.semibold))

            if controller.hasInputMonitoringPermission {
                Text("permission_granted_body")
            } else {
                Text("permission_body")
                Text("permission_privacy_note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if controller.hasInputMonitoringPermission {
                    Button("permission_close", action: onClose)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("permission_later", action: onClose)
                    Button("permission_open_settings") {
                        controller.openInputMonitoringSettings()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        // 日本語と英語で行数が変わるので、高さは中身に合わせる。
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(width: 380)
    }
}
