import AppKit
import SwiftUI

/// About ウインドウ。`WindowGroup` ではなく `Window` なので、何度開いても 1 枚しか出ない。
enum AboutWindow {
    static let id = "about"
}

/// バージョン・⌘英かなへの謝辞・GitHub へのリンクを出す（F-04 / N-05）。
struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            appIcon
            VStack(spacing: 4) {
                Text(AppInfo.name)
                    .font(.title2.weight(.semibold))
                Text("about_version \(AppInfo.versionText)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("about_summary")
            Divider()
            Text("about_credit")
            HStack(spacing: 16) {
                Link("about_repository", destination: AppInfo.repositoryURL)
                Link("about_cmd_eikana", destination: AppInfo.cmdEikanaURL)
            }
            .font(.callout)
            Text("about_license")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        // 日本語と英語で行数が変わるので、高さは中身に合わせる。
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(width: 340)
    }

    /// アプリのアイコン。#19 で差し替わるまでは、Xcode の既定のアイコンが出る。
    private var appIcon: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: 96, height: 96)
            .accessibilityHidden(true)
    }
}

#Preview {
    AboutView()
}
