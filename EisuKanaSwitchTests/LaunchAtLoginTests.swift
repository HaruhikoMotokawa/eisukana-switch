import Foundation
import ServiceManagement
import Testing
@testable import EisuKanaSwitch

/// `SMAppService` には触らず、登録状態をテストから自由に動かせるようにする。
@MainActor
final class FakeLoginItemService: LoginItemService {
    struct Failure: Error {}

    var status: SMAppService.Status
    /// `register()` したときに移る状態。承認待ちになる場合を再現できるようにする。
    var statusAfterRegister: SMAppService.Status = .enabled
    var shouldFail = false
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0
    private(set) var openSettingsCount = 0

    init(status: SMAppService.Status = .notRegistered) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if shouldFail { throw Failure() }
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCount += 1
        if shouldFail { throw Failure() }
        status = .notRegistered
    }

    func openSystemSettings() {
        openSettingsCount += 1
    }
}

@Suite("LaunchAtLogin")
@MainActor
struct LaunchAtLoginTests {
    @Test("起動時の表示はシステム側の登録状態から決める")
    func readsSystemStatus() {
        #expect(LaunchAtLogin(service: FakeLoginItemService(status: .enabled)).isOn)
        #expect(!LaunchAtLogin(service: FakeLoginItemService(status: .notRegistered)).isOn)
        #expect(!LaunchAtLogin(service: FakeLoginItemService(status: .notFound)).isOn)
    }

    @Test("承認待ちは ON として見せ、許可が必要なことを知らせる")
    func treatsRequiresApprovalAsOn() {
        let launchAtLogin = LaunchAtLogin(service: FakeLoginItemService(status: .requiresApproval))

        #expect(launchAtLogin.isOn)
        #expect(launchAtLogin.requiresApproval)
    }

    @Test("ON にすると登録する")
    func turningOnRegisters() {
        let service = FakeLoginItemService()
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.setOn(true)

        #expect(service.registerCount == 1)
        #expect(launchAtLogin.isOn)
        #expect(!launchAtLogin.requiresApproval)
    }

    @Test("OFF にすると登録を解除する")
    func turningOffUnregisters() {
        let service = FakeLoginItemService(status: .enabled)
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.setOn(false)

        #expect(service.unregisterCount == 1)
        #expect(!launchAtLogin.isOn)
    }

    @Test("登録して承認待ちになったら、そのことを知らせる")
    func reportsRequiresApprovalAfterRegister() {
        let service = FakeLoginItemService()
        service.statusAfterRegister = .requiresApproval
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.setOn(true)

        #expect(launchAtLogin.isOn)
        #expect(launchAtLogin.requiresApproval)
    }

    @Test("承認待ちから OFF にすると登録を解除する")
    func turningOffFromRequiresApprovalUnregisters() {
        let service = FakeLoginItemService(status: .requiresApproval)
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.setOn(false)

        #expect(service.unregisterCount == 1)
        #expect(!launchAtLogin.isOn)
        #expect(!launchAtLogin.requiresApproval)
    }

    @Test("登録に失敗したら、実際の状態のまま見せる")
    func keepsActualStatusOnFailure() {
        let service = FakeLoginItemService()
        service.shouldFail = true
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.setOn(true)

        #expect(service.registerCount == 1)
        #expect(!launchAtLogin.isOn)
    }

    @Test("同じ値をセットしても登録には触らない")
    func settingSameValueDoesNothing() {
        let service = FakeLoginItemService(status: .enabled)
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.setOn(true)

        #expect(service.registerCount == 0)
        #expect(service.unregisterCount == 0)
    }

    @Test("システム設定で変えられた状態を読み直す")
    func refreshPicksUpExternalChanges() {
        let service = FakeLoginItemService(status: .enabled)
        let launchAtLogin = LaunchAtLogin(service: service)

        // システム設定のログイン項目で外された。
        service.status = .notRegistered
        launchAtLogin.refresh()

        #expect(!launchAtLogin.isOn)
    }

    @Test("「システム設定を開く」でログイン項目を開く")
    func opensSystemSettings() {
        let service = FakeLoginItemService(status: .requiresApproval)
        let launchAtLogin = LaunchAtLogin(service: service)

        launchAtLogin.openSystemSettings()

        #expect(service.openSettingsCount == 1)
    }
}
