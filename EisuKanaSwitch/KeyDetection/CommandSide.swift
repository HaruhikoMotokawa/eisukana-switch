/// 左右どちらの ⌘ キーか。
enum CommandSide: Equatable, CaseIterable {
    case left
    case right

    /// `flagsChanged` の keyCode から左右を判定する。⌘ 以外なら nil。
    init?(keyCode: Int64) {
        switch keyCode {
        case Self.leftKeyCode: self = .left
        case Self.rightKeyCode: self = .right
        default: return nil
        }
    }

    /// `kVK_Command`
    static let leftKeyCode: Int64 = 55
    /// `kVK_RightCommand`
    static let rightKeyCode: Int64 = 54
}
