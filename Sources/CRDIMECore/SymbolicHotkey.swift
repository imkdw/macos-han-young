import Foundation

/// macOS "입력 메뉴에서 다음/이전 소스 선택" 단축키
/// com.apple.symbolichotkeys 의 AppleSymbolicHotKeys["61"] (다음), ["60"] (이전)
public struct SymbolicHotkey: Equatable {
    public let keycode: Int64
    /// NSEvent.ModifierFlags 비트. CGEventFlags와 값이 같다
    public let modifiers: UInt64

    public init(keycode: Int64, modifiers: UInt64) {
        self.keycode = keycode
        self.modifiers = modifiers
    }

    /// AppleSymbolicHotKeys 항목 하나를 해석한다. 꺼져 있거나 키가 없으면 nil
    public static func parse(_ entry: Any?) -> SymbolicHotkey? {
        guard let dict = entry as? [String: Any],
              (dict["enabled"] as? NSNumber)?.boolValue == true,
              let value = dict["value"] as? [String: Any],
              let params = value["parameters"] as? [NSNumber], params.count == 3
        else { return nil }
        let keycode = params[1].int64Value
        // 65535는 키가 지정되지 않은 상태
        guard keycode != 65535 else { return nil }
        return SymbolicHotkey(keycode: keycode, modifiers: params[2].uint64Value)
    }

    /// 다음 소스(61)를 우선, 없으면 이전 소스(60). 입력 소스가 두 개면 어느 쪽이든 토글이다
    public static func inputSourceHotkey(from hotkeys: [String: Any]?) -> SymbolicHotkey? {
        parse(hotkeys?["61"]) ?? parse(hotkeys?["60"])
    }

    public static func current() -> SymbolicHotkey? {
        let hotkeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys")
        return inputSourceHotkey(from: hotkeys)
    }
}
