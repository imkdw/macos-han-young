import AppKit
import ApplicationServices
import Foundation

// 키 입력 기록기 (listen only, 이벤트를 바꾸지 않는다)
// 로컬: Karabiner가 무엇을 내보내는지, 앞에 있는 앱이 무엇인지 확인
// 원격: CRD 호스트가 무엇을 주입하는지 확인
//
// 실행: swift run keylog            (저장소 안)
//       swift Sources/keylog/main.swift   (이 파일 하나만 있어도 됨)
// 기록 파일: ~/keylog-<호스트명>.txt

setvbuf(stdout, nil, _IOLBF, 0)

let keyNames: [Int64: String] = [
    57: "caps_lock", 79: "F18", 80: "F19", 64: "F17", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 90: "F20",
    49: "space", 36: "return", 48: "tab", 51: "delete", 53: "escape",
    55: "cmd", 54: "right_cmd", 56: "shift", 60: "right_shift", 58: "option", 61: "right_option",
    59: "control", 62: "right_control", 63: "fn", 102: "lang2(영)", 104: "lang1(한)",
]

let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("keylog-\(ProcessInfo.processInfo.hostName.components(separatedBy: ".")[0]).txt")
FileManager.default.createFile(atPath: logURL.path, contents: nil)
let logHandle = try! FileHandle(forWritingTo: logURL)

let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

func emit(_ line: String) {
    let stamped = "\(timeFormatter.string(from: Date())) \(line)"
    print(stamped)
    logHandle.write(Data("\(stamped)\n".utf8))
}

func processName(_ pid: Int64) -> String {
    guard pid > 0 else { return "0" }
    var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
    guard proc_pidpath(pid_t(pid), &buffer, UInt32(buffer.count)) > 0 else { return "\(pid)" }
    return "\(pid):\((String(cString: buffer) as NSString).lastPathComponent)"
}

let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
if !AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) {
    print("손쉬운 사용 권한이 필요합니다. 이 명령을 실행한 터미널 앱을 시스템 설정 > 손쉬운 사용 에서 켠 뒤 다시 실행하세요.")
    exit(1)
}

// userInfo로 어느 단계의 탭인지 구분한다 (0 = HID, 1 = session)
let callback: CGEventTapCallBack = { _, type, event, userInfo in
    let stage = userInfo == nil ? "HID    " : "session"
    let name: String
    switch type {
    case .keyDown: name = "keyDown     "
    case .keyUp: name = "keyUp       "
    case .flagsChanged: name = "flagsChanged"
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        emit("[\(stage)] 탭 비활성화됨, 다시 켬")
        return Unmanaged.passUnretained(event)
    default: return Unmanaged.passUnretained(event)
    }
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let label = keyNames[keycode].map { "\(keycode)(\($0))" } ?? "\(keycode)"
    let autorepeat = event.getIntegerValueField(.keyboardEventAutorepeat)
    let source = processName(event.getIntegerValueField(.eventSourceUnixProcessID))
    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
    emit("[\(stage)] \(name) key=\(label) repeat=\(autorepeat) flags=0x\(String(event.flags.rawValue, radix: 16)) src=\(source) front=\(front)")
    return Unmanaged.passUnretained(event)
}

let mask = [CGEventType.keyDown, .keyUp, .flagsChanged]
    .reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }

// HID 탭: 시스템 단축키가 가로채기 전 단계. session 탭: 앱으로 가기 직전 단계
for (location, info) in [(CGEventTapLocation.cghidEventTap, UnsafeMutableRawPointer?.none),
                         (.cgSessionEventTap, UnsafeMutableRawPointer(bitPattern: 1))] {
    guard let tap = CGEvent.tapCreate(
        tap: location, place: .headInsertEventTap, options: .listenOnly,
        eventsOfInterest: mask, callback: callback, userInfo: info
    ) else {
        print("이벤트 탭을 만들지 못했습니다 (\(location))")
        exit(1)
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
}

print("keylog 시작. 기록 파일: \(logURL.path)")
print("HID에만 찍히고 session에 없으면 macOS 단축키가 가져간 것입니다. 종료: Ctrl+C")
// 앞 앱 정보를 갱신하려면 NSApplication 런루프가 필요하다
NSApplication.shared.setActivationPolicy(.prohibited)
NSApplication.shared.run()
