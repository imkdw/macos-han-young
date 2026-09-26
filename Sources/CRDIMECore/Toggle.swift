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
/// CRD 호스트가 주입한 keycode(F18) 또는 crdKeycode(F19)만 트리거로 쓴다.
/// 로컬 키보드나 Karabiner에서 온 F18은 통과시킨다. 같은 맥에 로컬 규칙과 이 프로그램이 함께 있어도
/// 로컬 F18이 CRD로 넘어가야 상대 맥을 토글할 수 있기 때문이다 (A -> B, B -> A 양방향)
public func action(kind: KeyEventKind, keycode: Int64, isAutorepeat: Bool, fromCRD: Bool, config: Config) -> KeyAction {
    let isTrigger = fromCRD && (keycode == config.keycode || keycode == config.crdKeycode)
    guard isTrigger else { return .pass }
    switch kind {
    case .keyDown: return isAutorepeat ? .swallow : .toggleAndSwallow
    case .keyUp: return .swallow
    case .other: return .pass
    }
}
