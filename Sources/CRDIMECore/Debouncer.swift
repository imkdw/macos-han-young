import Foundation

/// CRD 호스트는 캡스락 한 번에 keyDown을 연달아 보내고(autorepeat 표시 없음) keyUp은 거의 보내지 않는다.
/// 마지막 keyDown 이후 window 안에 들어온 keyDown은 같은 누름으로 보고 무시한다.
public struct TriggerDebouncer {
    public let window: TimeInterval
    private var lastKeyDown: TimeInterval?

    public init(window: TimeInterval) {
        self.window = window
    }

    /// keyDown마다 호출. 새 누름이면 true
    public mutating func keyDown(at now: TimeInterval) -> Bool {
        defer { lastKeyDown = now }
        guard let last = lastKeyDown else { return true }
        return now - last > window
    }

    /// keyUp이 오면 다음 keyDown은 바로 새 누름으로 본다
    public mutating func keyUp() {
        lastKeyDown = nil
    }
}
