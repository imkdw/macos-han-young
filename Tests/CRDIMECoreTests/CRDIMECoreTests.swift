import Foundation
import CRDIMECore
import XCTest

final class ConfigTests: XCTestCase {
    func testDefaults() throws {
        XCTAssertEqual(try parseArguments([]), .run(Config()))
    }

    func testCustomValues() throws {
        var expected = Config()
        expected.englishID = "com.apple.keylayout.US"
        expected.koreanID = "com.apple.inputmethod.Korean.3SetKorean"
        expected.keycode = 80
        expected.crdKeycode = 81
        let args = ["--en", "com.apple.keylayout.US", "--ko", "com.apple.inputmethod.Korean.3SetKorean", "--keycode", "80", "--crd-keycode", "81"]
        XCTAssertEqual(try parseArguments(args), .run(expected))
        XCTAssertEqual(try parseArguments(args + ["--toggle"]), .toggleOnce(expected))
        XCTAssertEqual(try parseArguments(["--check"] + args), .check(expected))
    }

    func testListAndHelp() throws {
        XCTAssertEqual(try parseArguments(["--list"]), .list)
        XCTAssertEqual(try parseArguments(["--current"]), .current)
        XCTAssertEqual(try parseArguments(["-h"]), .help)
    }

    func testErrors() {
        XCTAssertThrowsError(try parseArguments(["--en"])) { XCTAssertEqual($0 as? ArgumentError, .missingValue("--en")) }
        XCTAssertThrowsError(try parseArguments(["--keycode", "abc"])) { XCTAssertEqual($0 as? ArgumentError, .invalidKeycode("abc")) }
        XCTAssertThrowsError(try parseArguments(["--keycode", "200"])) { XCTAssertEqual($0 as? ArgumentError, .invalidKeycode("200")) }
        XCTAssertThrowsError(try parseArguments(["--bogus"])) { XCTAssertEqual($0 as? ArgumentError, .unknownOption("--bogus")) }
    }
}

final class ToggleTests: XCTestCase {
    let config = Config()

    func testEnglishToKorean() {
        XCTAssertEqual(nextInputSourceID(current: Config.defaultEnglish, config: config), Config.defaultKorean)
    }

    func testKoreanToEnglish() {
        XCTAssertEqual(nextInputSourceID(current: Config.defaultKorean, config: config), Config.defaultEnglish)
    }

    // S5
    func testOtherSourceGoesToEnglish() {
        XCTAssertEqual(nextInputSourceID(current: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", config: config), Config.defaultEnglish)
        XCTAssertEqual(nextInputSourceID(current: nil, config: config), Config.defaultEnglish)
    }

    func testTriggerKeyDownToggles() {
        XCTAssertEqual(action(kind: .keyDown, keycode: 79, isAutorepeat: false, fromCRD: true, config: config), .toggleAndSwallow)
    }

    // F4
    func testAutorepeatIsSwallowedWithoutToggle() {
        XCTAssertEqual(action(kind: .keyDown, keycode: 79, isAutorepeat: true, fromCRD: true, config: config), .swallow)
    }

    func testTriggerKeyUpIsSwallowed() {
        XCTAssertEqual(action(kind: .keyUp, keycode: 79, isAutorepeat: false, fromCRD: true, config: config), .swallow)
    }

    // 양방향 설치: 이 맥의 로컬 키보드(Karabiner)에서 나온 F18은 CRD로 넘어가야 하므로 건드리지 않는다
    func testLocalF18PassesThrough() {
        XCTAssertEqual(action(kind: .keyDown, keycode: 79, isAutorepeat: false, fromCRD: false, config: config), .pass)
        XCTAssertEqual(action(kind: .keyUp, keycode: 79, isAutorepeat: false, fromCRD: false, config: config), .pass)
    }

    // CRD 호스트가 보낸 F19는 토글하고 삼킨다
    func testF19FromCRDToggles() {
        XCTAssertEqual(action(kind: .keyDown, keycode: 80, isAutorepeat: false, fromCRD: true, config: config), .toggleAndSwallow)
        XCTAssertEqual(action(kind: .keyUp, keycode: 80, isAutorepeat: false, fromCRD: true, config: config), .swallow)
        XCTAssertEqual(action(kind: .keyDown, keycode: 0, isAutorepeat: false, fromCRD: true, config: config), .pass)
    }

    // S3: 물리 캡스락(F19=80)은 건드리지 않는다
    func testOtherKeysPass() {
        XCTAssertEqual(action(kind: .keyDown, keycode: 80, isAutorepeat: false, fromCRD: false, config: config), .pass)
        XCTAssertEqual(action(kind: .keyDown, keycode: 0, isAutorepeat: false, fromCRD: false, config: config), .pass)
    }
}

final class DebouncerTests: XCTestCase {
    // CRD가 한 번 누름에 keyDown을 연달아 보내는 경우
    func testBurstCountsAsOnePress() {
        var d = TriggerDebouncer(window: 0.3)
        XCTAssertTrue(d.keyDown(at: 10.00))
        XCTAssertFalse(d.keyDown(at: 10.05))
        XCTAssertFalse(d.keyDown(at: 10.10))
        XCTAssertFalse(d.keyDown(at: 10.35))   // 마지막 keyDown 기준이라 버스트가 길어도 한 번
        XCTAssertTrue(d.keyDown(at: 11.00))
    }

    func testKeyUpResets() {
        var d = TriggerDebouncer(window: 0.3)
        XCTAssertTrue(d.keyDown(at: 10.00))
        d.keyUp()
        XCTAssertTrue(d.keyDown(at: 10.10))
    }

    func testDebounceOption() throws {
        guard case .run(let config) = try parseArguments(["--debounce", "150"]) else { return XCTFail() }
        XCTAssertEqual(config.debounceMs, 150)
        XCTAssertThrowsError(try parseArguments(["--debounce", "-1"]))
    }
}

final class SymbolicHotkeyTests: XCTestCase {
    func entry(enabled: Bool, keycode: Int, modifiers: Int) -> [String: Any] {
        ["enabled": NSNumber(value: enabled),
         "value": ["parameters": [NSNumber(value: 65535), NSNumber(value: keycode), NSNumber(value: modifiers)], "type": "standard"]]
    }

    func testParsesF19WithFn() {
        XCTAssertEqual(SymbolicHotkey.parse(entry(enabled: true, keycode: 80, modifiers: 8_388_608)),
                       SymbolicHotkey(keycode: 80, modifiers: 8_388_608))
    }

    func testDisabledOrUnassignedIsNil() {
        XCTAssertNil(SymbolicHotkey.parse(entry(enabled: false, keycode: 80, modifiers: 0)))
        XCTAssertNil(SymbolicHotkey.parse(entry(enabled: true, keycode: 65535, modifiers: 0)))
        XCTAssertNil(SymbolicHotkey.parse(nil))
    }

    func testPrefersNextThenPrevious() {
        let next = entry(enabled: true, keycode: 80, modifiers: 0)
        let previous = entry(enabled: true, keycode: 49, modifiers: 262_144)
        XCTAssertEqual(SymbolicHotkey.inputSourceHotkey(from: ["61": next, "60": previous])?.keycode, 80)
        XCTAssertEqual(SymbolicHotkey.inputSourceHotkey(from: ["60": previous])?.keycode, 49)
        XCTAssertNil(SymbolicHotkey.inputSourceHotkey(from: [:]))
    }

    func testMethodOption() throws {
        guard case .run(let config) = try parseArguments(["--method", "tis"]) else { return XCTFail() }
        XCTAssertEqual(config.method, .tis)
        XCTAssertThrowsError(try parseArguments(["--method", "x"]))
    }
}

final class CRDProcessTests: XCTestCase {
    func testCRDProcessOption() throws {
        guard case .run(let config) = try parseArguments(["--crd-process", "send-key"]) else { return XCTFail() }
        XCTAssertEqual(config.crdProcess, "send-key")
        XCTAssertEqual(Config().crdProcess, "remoting_me2me_host")
    }

    func testDetectorMatchesOwnProcessName() {
        let ownName = (CRDSourceDetector.executablePath(of: getpid())! as NSString).lastPathComponent
        XCTAssertTrue(CRDSourceDetector(processName: ownName).isCRDHost(pid: getpid()))
        XCTAssertFalse(CRDSourceDetector().isCRDHost(pid: getpid()))
        XCTAssertFalse(CRDSourceDetector().isCRDHost(pid: 0))
    }
}
