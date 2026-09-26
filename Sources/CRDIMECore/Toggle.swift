/// 현재가 한글이면 영문, 그 밖(영문, 일본어 등)이면 한글
/// PRD S5: 한/영 외 입력 소스에서는 영문으로 보낸다
public func nextInputSourceID(current: String?, config: Config) -> String {
    switch current {
    case config.englishID: return config.koreanID
    case config.koreanID: return config.englishID
    default: return config.englishID
    }
}

public enum KeyAction: Equatable {
    case pass
    case swallow
    case toggleAndSwallow
}

public enum KeyEventKind {
    case keyDown
    case keyUp
    case other
}

/// 이벤트 탭 콜백의 판단 로직 (F2, F4)
/// - keycode(F18): 출처와 무관하게 트리거
/// - crdKeycode(F19): CRD 호스트가 주입한 이벤트일 때만 트리거. 원격 시스템 단축키와 겹치지 않게 삼킨다
public func action(kind: KeyEventKind, keycode: Int64, isAutorepeat: Bool, fromCRD: Bool, config: Config) -> KeyAction {
    let isTrigger = keycode == config.keycode || (fromCRD && keycode == config.crdKeycode)
    guard isTrigger else { return .pass }
    switch kind {
    case .keyDown: return isAutorepeat ? .swallow : .toggleAndSwallow
    case .keyUp: return .swallow
    case .other: return .pass
    }
}
