import Carbon
import Foundation

public enum InputSource {
    public static func currentID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return id(of: source)
    }

    /// 선택 가능한 키보드 입력 소스 ID 목록
    public static func selectableIDs() -> [String] {
        let filter = [
            kTISPropertyInputSourceIsSelectCapable as String: true,
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
        ] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return list.compactMap(id(of:))
    }

    public static func find(_ id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource]
        return list?.first
    }

    @discardableResult
    public static func select(_ id: String) -> Bool {
        guard let source = find(id) else { return false }
        return TISSelectInputSource(source) == noErr
    }

    private static func id(of source: TISInputSource) -> String? {
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
}
