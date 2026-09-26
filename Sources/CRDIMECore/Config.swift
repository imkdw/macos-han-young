import Foundation

public struct Config: Equatable {
    public static let defaultEnglish = "com.apple.keylayout.ABC"
    public static let defaultKorean = "com.apple.inputmethod.Korean.2SetKorean"
    /// kVK_F18
    public static let defaultKeycode: Int64 = 79
    /// kVK_F19. CRD 호스트가 주입한 것만 트리거로 쓴다 (물리 키보드 F19는 통과)
    public static let defaultCRDKeycode: Int64 = 80
    public static let defaultDebounceMs = 300

    public var englishID = Config.defaultEnglish
    public var koreanID = Config.defaultKorean
    public var keycode = Config.defaultKeycode
    public var crdKeycode = Config.defaultCRDKeycode
    public var debounceMs = Config.defaultDebounceMs

    public init() {}
}

public enum Command: Equatable {
    /// 이벤트 탭을 걸고 상주한다
    case run(Config)
    /// 한 번만 토글하고 끝낸다 (테스트용)
    case toggleOnce(Config)
    /// 입력 소스 ID만 확인하고 끝낸다 (설치 스크립트용)
    case check(Config)
    /// 선택 가능한 입력 소스 목록을 출력한다
    case list
    /// 현재 입력 소스 ID를 출력한다
    case current
    case help
}

public enum ArgumentError: Error, Equatable, CustomStringConvertible {
    case missingValue(String)
    case invalidKeycode(String)
    case invalidNumber(String)
    case unknownOption(String)

    public var description: String {
        switch self {
        case .missingValue(let flag): return "\(flag) 뒤에 값이 필요합니다"
        case .invalidKeycode(let value): return "keycode는 0~127 정수여야 합니다: \(value)"
        case .invalidNumber(let value): return "debounce는 0~5000 정수(ms)여야 합니다: \(value)"
        case .unknownOption(let flag): return "알 수 없는 옵션: \(flag)"
        }
    }
}

public let usage = """
사용법: crd-ime-toggle [옵션]

  --en <id>        영문 입력 소스 ID (기본값: \(Config.defaultEnglish))
  --ko <id>        한글 입력 소스 ID (기본값: \(Config.defaultKorean))
  --keycode <n>    트리거 keycode, 출처 무관 (기본값: \(Config.defaultKeycode), F18)
  --crd-keycode <n>  CRD 호스트가 보낸 경우에만 트리거로 쓰는 keycode (기본값: \(Config.defaultCRDKeycode), F19)
  --debounce <ms>  이 시간 안에 연달아 온 keyDown은 한 번으로 처리 (기본값: \(Config.defaultDebounceMs))
  --toggle         이벤트 탭 없이 한 번만 토글하고 종료
  --check          입력 소스 ID가 유효한지만 확인하고 종료
  --list           선택 가능한 입력 소스 ID 목록 출력
  --current        현재 입력 소스 ID 출력
  -h, --help       이 도움말
"""

public func parseArguments(_ args: [String]) throws -> Command {
    var config = Config()
    var mode = "run"
    var i = 0

    func value(after flag: String) throws -> String {
        i += 1
        guard i < args.count else { throw ArgumentError.missingValue(flag) }
        return args[i]
    }

    while i < args.count {
        let arg = args[i]
        switch arg {
        case "--en": config.englishID = try value(after: arg)
        case "--ko": config.koreanID = try value(after: arg)
        case "--keycode":
            let raw = try value(after: arg)
            guard let code = Int64(raw), (0...127).contains(code) else {
                throw ArgumentError.invalidKeycode(raw)
            }
            config.keycode = code
        case "--crd-keycode":
            let raw = try value(after: arg)
            guard let code = Int64(raw), (0...127).contains(code) else {
                throw ArgumentError.invalidKeycode(raw)
            }
            config.crdKeycode = code
        case "--debounce":
            let raw = try value(after: arg)
            guard let ms = Int(raw), (0...5000).contains(ms) else {
                throw ArgumentError.invalidNumber(raw)
            }
            config.debounceMs = ms
        case "--toggle": mode = "toggle"
        case "--check": mode = "check"
        case "--list": return .list
        case "--current": return .current
        case "-h", "--help": return .help
        default: throw ArgumentError.unknownOption(arg)
        }
        i += 1
    }
    switch mode {
    case "toggle": return .toggleOnce(config)
    case "check": return .check(config)
    default: return .run(config)
    }
}
