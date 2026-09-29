import Foundation
import os

/// 切り替えの結果。
enum InputSourceSwitchResult: Equatable, Sendable {
    /// 切り替えた。
    case switched(id: String)
    /// すでに目的のモードだったので、何もしなかった。
    case alreadyActive
    /// 有効な入力ソースに候補が無かった。
    /// 英数でこれが返るのは、ABC などを無効にして IME だけを使っている環境。
    case noCandidate
    /// `TISSelectInputSource` が失敗した。
    case failed(OSStatus)
}

/// 入力ソースを英数 / かなへ切り替える。#3 の検出結果はここへ入ってくる。
@MainActor
protocol InputSourceSwitching: AnyObject {
    @discardableResult
    func activate(_ target: InputSourceTarget) -> InputSourceSwitchResult
}

extension InputSourceSwitching {
    /// 左 ⌘ なら英数、右 ⌘ ならかなへ切り替える（F-01 / F-02）。
    @discardableResult
    func activate(for side: CommandSide) -> InputSourceSwitchResult {
        activate(side.inputSourceTarget)
    }
}

/// `InputSourceRepository` から状態を集めて `InputSourceSelector` に渡し、結果を適用する。
@MainActor
final class InputSourceSwitcher: InputSourceSwitching {
    private let repository: InputSourceRepository
    private let logger: Logger

    /// 直前に離れたかな入力ソースのバンドル ID。
    /// ABC ↔ かなを往復するとき、複数 IME を有効にしていても元の IME に戻れるようにする。
    private var preferredKanaBundleID: String?

    init(
        repository: InputSourceRepository,
        logger: Logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "io.github.haruhikomotokawa.EisuKanaSwitch",
            category: "InputSource"
        )
    ) {
        self.repository = repository
        self.logger = logger
    }

    @discardableResult
    func activate(_ target: InputSourceTarget) -> InputSourceSwitchResult {
        let current = repository.currentSource()
        rememberKanaSource(current)

        let enabled = repository.enabledSources()
        let selection = InputSourceSelector.selection(
            for: target,
            current: current,
            enabled: enabled,
            asciiCapableSourceID: repository.asciiCapableSourceID(),
            preferredKanaBundleID: preferredKanaBundleID
        )

        switch selection {
        case .alreadyActive:
            return .alreadyActive
        case .noCandidate:
            // 英数の候補が無い環境（ABC を無効にして IME だけにしている等）。
            // メニューでの案内は #5 / #6 で扱う。
            logger.notice("no input source for \(target.rawValue, privacy: .public)")
            return .noCandidate
        case .select(let descriptor):
            let status = repository.select(descriptor)
            guard status == noErr else {
                logger.error("TISSelectInputSource(\(descriptor.id, privacy: .public)) failed: \(status)")
                return .failed(status)
            }
            logger.debug("\(target.rawValue, privacy: .public) -> \(descriptor.id, privacy: .public)")
            return .switched(id: descriptor.id)
        }
    }

    /// かなモードから離れる直前に、その IME を覚えておく。
    private func rememberKanaSource(_ current: InputSourceDescriptor?) {
        guard let current, current.isKanaMode, let bundleID = current.bundleID else { return }
        preferredKanaBundleID = bundleID
    }
}
