import Foundation

/// Control과 Command를 맞바꾼다. CGEventFlags 원시값과 수식키 keycode를 다룬다
public enum ModifierSwap {
    /// (Control 쪽 비트, Command 쪽 비트). 장치 독립 비트, 왼쪽 키 비트, 오른쪽 키 비트 순서
    static let flagPairs: [(UInt64, UInt64)] = [
        (0x0004_0000, 0x0010_0000),
        (0x0000_0001, 0x0000_0008),
        (0x0000_2000, 0x0000_0010),
    ]

    public static func flags(_ raw: UInt64) -> UInt64 {
        var result = raw
        for (control, command) in flagPairs {
            result &= ~(control | command)
            if raw & control != 0 { result |= command }
            if raw & command != 0 { result |= control }
        }
        return result
    }

    /// kVK_Control 59, kVK_RightControl 62, kVK_Command 55, kVK_RightCommand 54. 그 밖의 키는 그대로
    public static func keycode(_ keycode: Int64) -> Int64 {
        switch keycode {
        case 59: return 55
        case 55: return 59
        case 62: return 54
        case 54: return 62
        default: return keycode
        }
    }
}
