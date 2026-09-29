import Carbon
import Foundation

/// 入力ソースの読み取りと選択。Carbon（Text Input Services）をこの裏に閉じ込める。
@MainActor
protocol InputSourceRepository {
    /// 有効かつ選択可能なキーボード入力ソースを、ユーザーが並べた順で返す。
    func enabledSources() -> [InputSourceDescriptor]
    /// 現在の入力ソース。取得できなければ nil。
    func currentSource() -> InputSourceDescriptor?
    /// 直近に使った ASCII 入力可能なキーボードレイアウトの ID。
    /// 有効な入力ソースとは限らないので、呼び出し側で一覧と突き合わせる。
    func asciiCapableSourceID() -> String?
    /// 入力ソースを選ぶ。`noErr` なら成功。
    func select(_ descriptor: InputSourceDescriptor) -> OSStatus
}

/// `TISInputSource` を使う実装。
@MainActor
final class CarbonInputSourceRepository: InputSourceRepository {
    /// `select(_:)` のために、ID から `TISInputSource` を引けるようにしておく。
    /// `enabledSources()` を呼ぶたびに作り直す。
    private var sourcesByID: [String: TISInputSource] = [:]

    func enabledSources() -> [InputSourceDescriptor] {
        // 第 2 引数が false なので、有効なものだけが返る。無効な入力ソースを
        // TISSelectInputSource に渡しても paramErr になるだけなので、ここで絞っておく。
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        var descriptors: [InputSourceDescriptor] = []
        var byID: [String: TISInputSource] = [:]
        for source in list {
            guard Self.isSelectableKeyboardSource(source),
                  let descriptor = Self.descriptor(for: source) else { continue }
            descriptors.append(descriptor)
            byID[descriptor.id] = source
        }
        sourcesByID = byID
        return descriptors
    }

    func currentSource() -> InputSourceDescriptor? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return Self.descriptor(for: source)
    }

    func asciiCapableSourceID() -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return Self.string(source, kTISPropertyInputSourceID)
    }

    func select(_ descriptor: InputSourceDescriptor) -> OSStatus {
        guard let source = sourcesByID[descriptor.id] else { return OSStatus(paramErr) }
        return TISSelectInputSource(source)
    }

    // MARK: - TISInputSource の読み取り

    /// パレット（絵文字ビューアなど）や、モードを持つ IME 本体のような選べないものを除く。
    private static func isSelectableKeyboardSource(_ source: TISInputSource) -> Bool {
        guard string(source, kTISPropertyInputSourceCategory) == (kTISCategoryKeyboardInputSource as String) else {
            return false
        }
        return bool(source, kTISPropertyInputSourceIsSelectCapable) ?? false
    }

    private static func descriptor(for source: TISInputSource) -> InputSourceDescriptor? {
        guard let id = string(source, kTISPropertyInputSourceID) else { return nil }
        return InputSourceDescriptor(
            id: id,
            bundleID: string(source, kTISPropertyBundleID),
            inputModeID: string(source, kTISPropertyInputModeID),
            isKeyboardLayout: string(source, kTISPropertyInputSourceType) == (kTISTypeKeyboardLayout as String),
            isASCIICapable: bool(source, kTISPropertyInputSourceIsASCIICapable) ?? false,
            localizedName: string(source, kTISPropertyLocalizedName)
        )
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? String
    }

    private static func bool(_ source: TISInputSource, _ key: CFString) -> Bool? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? Bool
    }
}
