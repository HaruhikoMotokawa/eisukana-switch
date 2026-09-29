import Foundation
import Testing
@testable import EisuKanaSwitch

/// 入力ソースを実際には変えずに、切り替えの呼び出しだけを記録する。
@MainActor
final class FakeInputSourceRepository: InputSourceRepository {
    var current: InputSourceDescriptor?
    var enabled: [InputSourceDescriptor]
    var asciiCapableID: String?
    var selectStatus: OSStatus = noErr
    private(set) var selected: [InputSourceDescriptor] = []

    init(
        current: InputSourceDescriptor?,
        enabled: [InputSourceDescriptor],
        asciiCapableID: String? = nil
    ) {
        self.current = current
        self.enabled = enabled
        self.asciiCapableID = asciiCapableID
    }

    func enabledSources() -> [InputSourceDescriptor] { enabled }
    func currentSource() -> InputSourceDescriptor? { current }
    func asciiCapableSourceID() -> String? { asciiCapableID }

    func select(_ descriptor: InputSourceDescriptor) -> OSStatus {
        selected.append(descriptor)
        if selectStatus == noErr { current = descriptor }
        return selectStatus
    }
}

@Suite("InputSourceSwitcher")
@MainActor
struct InputSourceSwitcherTests {
    @Test("左 ⌘ で英数、右 ⌘ でかなへ切り替える")
    func switchesForBothCommandKeys() {
        let repository = FakeInputSourceRepository(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: InputSourceFixtures.kotoeriOnly
        )
        let switcher = InputSourceSwitcher(repository: repository)

        #expect(switcher.activate(for: .left) == .switched(id: InputSourceFixtures.abc.id))
        #expect(switcher.activate(for: .right) == .switched(id: InputSourceFixtures.kotoeriHiragana.id))
        #expect(repository.selected.map(\.id) == [InputSourceFixtures.abc.id, InputSourceFixtures.kotoeriHiragana.id])
    }

    @Test("すでに目的のモードなら TISSelectInputSource を呼ばない")
    func doesNotSelectWhenAlreadyActive() {
        let repository = FakeInputSourceRepository(
            current: InputSourceFixtures.abc,
            enabled: InputSourceFixtures.kotoeriOnly
        )
        let switcher = InputSourceSwitcher(repository: repository)

        #expect(switcher.activate(.eisu) == .alreadyActive)
        #expect(repository.selected.isEmpty)
    }

    @Test("候補が無ければ noCandidate を返す")
    func reportsNoCandidate() {
        let repository = FakeInputSourceRepository(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: InputSourceFixtures.japaneseOnly
        )
        let switcher = InputSourceSwitcher(repository: repository)

        #expect(switcher.activate(.eisu) == .noCandidate)
        #expect(repository.selected.isEmpty)
    }

    @Test("選択に失敗したら OSStatus を添えて failed を返す")
    func reportsFailureStatus() {
        let repository = FakeInputSourceRepository(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: InputSourceFixtures.kotoeriOnly
        )
        repository.selectStatus = OSStatus(-50)
        let switcher = InputSourceSwitcher(repository: repository)

        #expect(switcher.activate(.eisu) == .failed(OSStatus(-50)))
    }

    @Test("ABC を経由しても、直前に使っていた IME のかなへ戻る")
    func remembersLastKanaInputMethod() {
        let enabled = [
            InputSourceFixtures.abc,
            InputSourceFixtures.kotoeriHiragana,
            InputSourceFixtures.googleHiragana,
        ]
        // 一覧の先頭のかなはことえりだが、直前に使っていたのは Google 日本語入力。
        let repository = FakeInputSourceRepository(current: InputSourceFixtures.googleHiragana, enabled: enabled)
        let switcher = InputSourceSwitcher(repository: repository)

        #expect(switcher.activate(.eisu) == .switched(id: InputSourceFixtures.abc.id))
        #expect(switcher.activate(.kana) == .switched(id: InputSourceFixtures.googleHiragana.id))
    }

    @Test("英数を続けて押しても、2 回目は何も起きない")
    func isIdempotent() {
        let repository = FakeInputSourceRepository(
            current: InputSourceFixtures.kotoeriHiragana,
            enabled: InputSourceFixtures.kotoeriOnly
        )
        let switcher = InputSourceSwitcher(repository: repository)

        #expect(switcher.activate(.eisu) == .switched(id: InputSourceFixtures.abc.id))
        #expect(switcher.activate(.eisu) == .alreadyActive)
        #expect(repository.selected.count == 1)
    }
}

@Suite("CarbonInputSourceRepository")
@MainActor
struct CarbonInputSourceRepositoryTests {
    /// 実機の入力ソースを読むだけ。入力ソースの切り替えはしない。
    @Test("有効な入力ソースを読み出せる")
    func readsEnabledSources() {
        let repository = CarbonInputSourceRepository()
        let sources = repository.enabledSources()

        #expect(!sources.isEmpty)
        #expect(sources.allSatisfy { !$0.id.isEmpty })
        #expect(Set(sources.map(\.id)).count == sources.count)
    }
}

/// 実機の入力ソースを実際に切り替える。テスト中は入力ソースが変わるので、
/// 環境変数 `EISUKANA_RUN_LIVE_TESTS=1` を与えたときだけ動く。
/// Xcode ではスキームの Test > Arguments にこの環境変数があるので、チェックを入れれば実行できる。
@Suite("実機での切り替え", .enabled(if: ProcessInfo.processInfo.environment["EISUKANA_RUN_LIVE_TESTS"] == "1"))
@MainActor
struct LiveInputSourceSwitchTests {
    @Test("英数 → かな → 英数 と切り替えられる")
    func switchesRealInputSource() {
        let repository = CarbonInputSourceRepository()
        let switcher = InputSourceSwitcher(repository: repository)
        let enabled = repository.enabledSources()
        // 英数とかなの両方の候補が無い環境では、確かめようがないので何もしない。
        guard enabled.contains(where: \.isEisu), enabled.contains(where: \.isKanaMode) else { return }

        let original = repository.currentSource()
        defer {
            if let original { _ = repository.select(original) }
        }

        // 開始時の入力ソースに関係なく、実際の切り替えを 3 回とも通るようにする。
        expectActivation(switcher, .eisu, repository) { $0.isEisu }
        expectActivation(switcher, .kana, repository) { $0.isKanaMode }
        expectActivation(switcher, .eisu, repository) { $0.isEisu }
    }

    private func expectActivation(
        _ switcher: InputSourceSwitcher,
        _ target: InputSourceTarget,
        _ repository: CarbonInputSourceRepository,
        _ isExpectedMode: (InputSourceDescriptor) -> Bool
    ) {
        let result = switcher.activate(target)
        #expect(result != .noCandidate, "\(target) の候補が見つからなかった")
        if case .failed(let status) = result {
            Issue.record("TISSelectInputSource が失敗した: \(status)")
        }
        guard let current = repository.currentSource() else {
            Issue.record("現在の入力ソースを読めなかった")
            return
        }
        #expect(isExpectedMode(current), "\(target) に切り替わらなかった: \(current.id)")
    }
}
