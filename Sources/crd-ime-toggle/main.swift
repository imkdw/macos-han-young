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

// auto: 시스템 한영전환 단축키가 있으면 CRD가 보낸 키를 그 단축키로 바꿔서 넘긴다
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

/// CRD가 주입한 트리거 이벤트를 시스템 한영전환 단축키로 고쳐 쓴다. 고친 이벤트는 삼키지 않고 그대로 넘긴다.
/// 키 이벤트를 새로 만들어 주입하면 안 된다. CRD 호스트가 로컬 사용자의 입력으로 보고 원격 키보드와 마우스를 2초간 막는다.
/// 받은 이벤트를 고치면 출처가 CRD 호스트로 남아 막히지 않고, 시스템 단축키 경로를 타므로 앱에도 바로 반영된다
func rewriteAsSystemHotkey(_ event: CGEvent, _ hotkey: SymbolicHotkey) {
    event.setIntegerValueField(.keyboardEventKeycode, value: hotkey.keycode)
    event.flags = CGEventFlags(rawValue: hotkey.modifiers)
}

var toggleGeneration = 0

/// 입력 소스를 직접 선택해 토글한다 (tis 방식, --toggle)
func selectNextInputSource() {
    let current = InputSource.currentID()
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
    selectNextInputSource()
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
    let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
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
    case .swallow:
        // 단축키 방식: keyDown을 단축키로 넘겼으니 짝이 되는 keyUp도 같은 키로 넘긴다
        if let hotkey, kind == .keyUp {
            rewriteAsSystemHotkey(event, hotkey)
            return Unmanaged.passUnretained(event)
        }
        return nil
    case .toggleAndSwallow:
        guard debouncer.keyDown(at: ProcessInfo.processInfo.systemUptime) else { return nil }
        guard let hotkey else {
            selectNextInputSource()
            return nil
        }
        let current = InputSource.currentID()
        rewriteAsSystemHotkey(event, hotkey)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            log("\(current ?? "?") -> \(InputSource.currentID() ?? "?") (hotkey)")
        }
        return Unmanaged.passUnretained(event)
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
