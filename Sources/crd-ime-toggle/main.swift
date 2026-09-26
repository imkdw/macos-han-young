import ApplicationServices
import CRDIMECore
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
setvbuf(stderr, nil, _IOLBF, 0)

let logFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

func log(_ message: String) {
    let stamp = logFormatter.string(from: Date())
    print("[\(stamp)] \(message)")
}

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(code)
}

// MARK: - 인자

let command: Command
do {
    command = try parseArguments(Array(CommandLine.arguments.dropFirst()))
} catch {
    fail("\(error)\n\n\(usage)", code: 64)
}

let config: Config
switch command {
case .help:
    print(usage)
    exit(0)
case .list:
    InputSource.selectableIDs().forEach { print($0) }
    exit(0)
case .current:
    print(InputSource.currentID() ?? "?")
    exit(0)
case .run(let c), .toggleOnce(let c), .check(let c):
    config = c
}

// 두 ID를 못 찾으면 활성 입력 소스 목록을 보여주고 끝낸다 (EX_CONFIG)
let missing = [config.englishID, config.koreanID].filter { InputSource.find($0) == nil }
if !missing.isEmpty {
    let available = InputSource.selectableIDs().map { "  \($0)" }.joined(separator: "\n")
    fail("입력 소스를 찾지 못했습니다: \(missing.joined(separator: ", "))\n선택 가능한 입력 소스:\n\(available)", code: 78)
}
if case .check = command {
    print("ok: en=\(config.englishID) ko=\(config.koreanID) keycode=\(config.keycode) crd-keycode=\(config.crdKeycode)")
    exit(0)
}

// MARK: - 토글

let ownPID = Int64(getpid())

// auto: 시스템 한영전환 단축키가 있으면 그걸 대신 누른다
let hotkey: SymbolicHotkey? = {
    switch config.method {
    case .tis: return nil
    case .hotkey, .auto:
        let found = SymbolicHotkey.current()
        if found == nil, config.method == .hotkey {
            fail("시스템 설정 > 키보드 > 키보드 단축키 > 입력 소스 에 단축키가 없습니다. --method tis 를 쓰거나 단축키를 등록하세요.", code: 78)
        }
        return found
    }
}()

/// 시스템 단축키를 실제 키 입력처럼 HID 단계에 주입한다. 로컬 캡스락과 같은 경로라 앱에 확실히 반영된다
func pressSystemHotkey(_ hotkey: SymbolicHotkey) {
    let source = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(hotkey.keycode), keyDown: down) else { return }
        event.flags = CGEventFlags(rawValue: hotkey.modifiers)
        event.post(tap: .cghidEventTap)
    }
}

var toggleGeneration = 0

func toggle() {
    let current = InputSource.currentID()

    if let hotkey {
        pressSystemHotkey(hotkey)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            log("\(current ?? "?") -> \(InputSource.currentID() ?? "?") (hotkey)")
        }
        return
    }

    toggleGeneration += 1
    let generation = toggleGeneration
    let target = nextInputSourceID(current: current, config: config)
    guard InputSource.select(target) else {
        log("선택 실패: \(target)")
        return
    }
    log("\(current ?? "?") -> \(target) (tis)")

    // R4: 한글 입력기를 선택한 직후 반영이 안 되는 경우가 있어 한 번 확인하고 다시 선택한다
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
        // 그 사이 다른 토글이 있었으면 건드리지 않는다
        if generation == toggleGeneration, InputSource.currentID() != target {
            log("재선택: \(target)")
            InputSource.select(target)
        }
    }
}

if case .toggleOnce = command {
    toggle()
    // 재선택 확인이 끝날 때까지 기다린다
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    print(InputSource.currentID() ?? "?")
    exit(0)
}

// MARK: - 권한 (N3: 손쉬운 사용 하나만)

let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
if !AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) {
    log("손쉬운 사용 권한이 필요합니다. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 \(CommandLine.arguments[0]) 를 켜주세요.")
    log("권한이 허용될 때까지 기다립니다...")
    while !AXIsProcessTrusted() {
        Thread.sleep(forTimeInterval: 2)
    }
    log("권한 확인됨")
}

// MARK: - 이벤트 탭

var eventTap: CFMachPort?
let crdDetector = CRDSourceDetector(processName: config.crdProcess)
var debouncer = TriggerDebouncer(window: Double(config.debounceMs) / 1000)

let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        // F5: 비활성화되면 다시 켠다
        log("이벤트 탭 재활성화 (\(type == .tapDisabledByTimeout ? "timeout" : "user input"))")
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    default:
        break
    }

    let kind: KeyEventKind = type == .keyDown ? .keyDown : (type == .keyUp ? .keyUp : .other)
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    // 우리가 주입한 단축키 이벤트는 건드리지 않는다
    let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
    if sourcePID == ownPID { return Unmanaged.passUnretained(event) }
    // 트리거 후보 keycode일 때만 출처 프로세스를 확인한다
    var fromCRD = false
    if keycode == config.keycode || keycode == config.crdKeycode {
        fromCRD = crdDetector.isCRDHost(pid: pid_t(sourcePID))
    }
    let result = action(
        kind: kind,
        keycode: keycode,
        isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
        fromCRD: fromCRD,
        config: config
    )
    if result == .swallow, kind == .keyUp {
        debouncer.keyUp()
    }
    switch result {
    case .pass: return Unmanaged.passUnretained(event)
    case .swallow: return nil
    case .toggleAndSwallow:
        if debouncer.keyDown(at: ProcessInfo.processInfo.systemUptime) {
            toggle()
        }
        return nil
    }
}

let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: callback,
    userInfo: nil
) else {
    fail("이벤트 탭을 만들지 못했습니다. 손쉬운 사용 권한을 확인하세요.", code: 1)
}
eventTap = tap

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

log("시작: keycode=\(config.keycode) crd-keycode=\(config.crdKeycode) crd-process=\(config.crdProcess) debounce=\(config.debounceMs)ms method=\(hotkey.map { "hotkey(keycode=\($0.keycode))" } ?? "tis") en=\(config.englishID) ko=\(config.koreanID)")
CFRunLoopRun()
