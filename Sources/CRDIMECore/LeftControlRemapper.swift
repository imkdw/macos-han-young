import Foundation

/// 왼쪽 Control만 Command로 바꾼다.
/// CRD 호스트가 넣는 이벤트의 flags에는 좌우 구분 비트가 없어서, flagsChanged의 keycode로 좌우 눌림 상태를 따라간다
public struct LeftControlRemapper {
    static let control: UInt64 = 0x0004_0000
    static let command: UInt64 = 0x0010_0000
    /// kVK_Control, kVK_RightControl, kVK_Command
    static let leftControlKeycode: Int64 = 59
    static let rightControlKeycode: Int64 = 62
    static let commandKeycode: Int64 = 55

    public private(set) var leftDown = false
    public private(set) var rightDown = false

    public init() {}

    /// flagsChanged마다 호출한다. 바꿔 쓸 keycode를 돌려준다
    public mutating func modifierChanged(keycode: Int64, flags: UInt64) -> Int64 {
        let controlOn = flags & Self.control != 0
        if !controlOn {
            leftDown = false
            rightDown = false
        } else if keycode == Self.leftControlKeycode {
            leftDown = rightDown ? !leftDown : true
        } else if keycode == Self.rightControlKeycode {
            rightDown = leftDown ? !rightDown : true
        }
        return keycode == Self.leftControlKeycode ? Self.commandKeycode : keycode
    }

    /// 지금 눌림 상태에 맞춰 flags를 고쳐 쓴다
    public func flags(_ raw: UInt64) -> UInt64 {
        guard raw & Self.control != 0 else { return raw }
        var result = raw & ~Self.control
        if rightDown { result |= Self.control }
        if leftDown || !rightDown { result |= Self.command }
        return result
    }
}
