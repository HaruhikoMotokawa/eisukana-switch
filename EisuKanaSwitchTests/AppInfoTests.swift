import Testing
@testable import EisuKanaSwitch

@Suite("AppInfo")
struct AppInfoTests {
    @Test("バージョンとビルド番号を並べる")
    func combinesVersionAndBuild() {
        #expect(AppInfo.versionText(shortVersion: "0.1.0", build: "1") == "0.1.0 (1)")
        #expect(AppInfo.versionText(shortVersion: "1.2.3", build: "42") == "1.2.3 (42)")
    }

    @Test("ビルド番号が無ければバージョンだけにする")
    func omitsEmptyBuild() {
        #expect(AppInfo.versionText(shortVersion: "0.1.0", build: "") == "0.1.0")
    }

    /// `CURRENT_PROJECT_VERSION` を設定し忘れると、両方に同じ値が入ることがある。
    @Test("ビルド番号がバージョンと同じなら括弧を付けない")
    func omitsRedundantBuild() {
        #expect(AppInfo.versionText(shortVersion: "0.1.0", build: "0.1.0") == "0.1.0")
    }

    @Test("リンク先が README と同じリポジトリを指している")
    func linksPointAtTheRightRepositories() {
        #expect(AppInfo.repositoryURL.absoluteString == "https://github.com/HaruhikoMotokawa/eisukana-switch")
        #expect(AppInfo.cmdEikanaURL.absoluteString == "https://github.com/iMasanari/cmd-eikana")
    }
}
