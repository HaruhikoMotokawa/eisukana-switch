import Foundation
import Testing
@testable import EisuKanaSwitch

/// `CGEventTap` は作らず、開始 / 停止の呼ばれ方だけを記録する。
@MainActor
final class FakeCommandKeyMonitor: CommandKeyMonitoring {
    var onSoloCommand: ((CommandSide) -> Void)?
    /// 入力監視が未許可の状況を再現するときに false にする。
    var canStart = true
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    @discardableResult
    func start() -> Bool {
        startCount += 1
        isRunning = canStart
        return canStart
    }

    func stop() {
        stopCount += 1
        isRunning = false
    }

    /// タップからの通知を模して、単独押下を流し込む。
    func emit(_ side: CommandSide) {
        onSoloCommand?(side)
    }
}

/// `UserDefaults` を触らずに、保存された値だけを持つ。
@MainActor
final class FakeEnabledStateStore: EnabledStateStore {
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}

/// 入力ソースには触らず、切り替えの要求だけを記録する。
@MainActor
final class FakeInputSourceSwitcher: InputSourceSwitching {
    private(set) var activated: [InputSourceTarget] = []

    @discardableResult
    func activate(_ target: InputSourceTarget) -> InputSourceSwitchResult {
        activated.append(target)
        return .switched(id: target.rawValue)
    }
}

@Suite("SwitchingController")
@MainActor
struct SwitchingControllerTests {
    /// テスト対象と、覗き込むためのフェイクをまとめて作る。
    private static func make(
        storedIsEnabled: Bool = true
    ) -> (SwitchingController, FakeCommandKeyMonitor, FakeInputSourceSwitcher, FakeEnabledStateStore) {
        let monitor = FakeCommandKeyMonitor()
        let switcher = FakeInputSourceSwitcher()
        let store = FakeEnabledStateStore(isEnabled: storedIsEnabled)
        let controller = SwitchingController(monitor: monitor, switcher: switcher, store: store)
        return (controller, monitor, switcher, store)
    }

    @Test("保存された有効/無効を起動時に引き継ぐ")
    func restoresStoredState() {
        let (enabled, _, _, _) = Self.make(storedIsEnabled: true)
        #expect(enabled.isEnabled)

        let (disabled, _, _, _) = Self.make(storedIsEnabled: false)
        #expect(!disabled.isEnabled)
    }

    @Test("有効なら起動時に監視を始める")
    func startsMonitorWhenEnabled() {
        let (controller, monitor, _, _) = Self.make(storedIsEnabled: true)

        controller.start()

        #expect(monitor.isRunning)
        #expect(monitor.startCount == 1)
    }

    @Test("無効なら起動時に監視を始めない")
    func doesNotStartMonitorWhenDisabled() {
        let (controller, monitor, _, _) = Self.make(storedIsEnabled: false)

        controller.start()

        #expect(!monitor.isRunning)
        #expect(monitor.startCount == 0)
    }

    @Test("左 ⌘ で英数、右 ⌘ でかなへ切り替える")
    func activatesTargetForEachSide() {
        let (controller, monitor, switcher, _) = Self.make()
        controller.start()

        monitor.emit(.left)
        monitor.emit(.right)

        #expect(switcher.activated == [.eisu, .kana])
    }

    @Test("無効にすると監視を止め、設定を保存する")
    func disablingStopsMonitorAndPersists() {
        let (controller, monitor, _, store) = Self.make()
        controller.start()

        controller.setEnabled(false)

        #expect(!controller.isEnabled)
        #expect(!monitor.isRunning)
        #expect(monitor.stopCount == 1)
        #expect(!store.isEnabled)
    }

    @Test("有効に戻すと監視を再開し、設定を保存する")
    func enablingStartsMonitorAndPersists() {
        let (controller, monitor, _, store) = Self.make(storedIsEnabled: false)
        controller.start()

        controller.setEnabled(true)

        #expect(controller.isEnabled)
        #expect(monitor.isRunning)
        #expect(monitor.startCount == 1)
        #expect(store.isEnabled)
    }

    @Test("無効の間に届いたイベントでは切り替えない")
    func ignoresEventsWhileDisabled() {
        let (controller, monitor, switcher, _) = Self.make()
        controller.start()
        controller.setEnabled(false)

        monitor.emit(.left)

        #expect(switcher.activated.isEmpty)
    }

    @Test("同じ値をセットしても監視には触らない")
    func settingSameValueDoesNothing() {
        let (controller, monitor, _, _) = Self.make()
        controller.start()

        controller.setEnabled(true)

        #expect(monitor.startCount == 1)
        #expect(monitor.stopCount == 0)
    }

    @Test("入力監視が未許可でも、有効のまま扱う")
    func staysEnabledWhenMonitorCannotStart() {
        let (controller, monitor, _, store) = Self.make()
        monitor.canStart = false

        controller.start()

        // 権限の案内と、許可後の再試行は #6（F-06）で扱う。
        #expect(controller.isEnabled)
        #expect(store.isEnabled)
        #expect(!monitor.isRunning)
    }

    @Test("終了時に監視を止める")
    func stopStopsMonitor() {
        let (controller, monitor, _, _) = Self.make()
        controller.start()

        controller.stop()

        #expect(!monitor.isRunning)
        #expect(monitor.stopCount == 1)
    }
}
