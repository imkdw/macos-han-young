// 테스트용: 합성 키 이벤트를 HID 레벨에 주입한다
// 사용법: swift scripts/send-key.swift <keycode> [repeat]
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count >= 2, let keycode = CGKeyCode(args[1]) else {
    print("사용법: swift scripts/send-key.swift <keycode> [repeat]")
    exit(64)
}
let isRepeat = args.count >= 3 && args[2] == "repeat"
let source = CGEventSource(stateID: .hidSystemState)
for down in [true, false] {
    let event = CGEvent(keyboardEventSource: source, virtualKey: keycode, keyDown: down)!
    if isRepeat { event.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
    event.post(tap: .cghidEventTap)
    usleep(20_000)
}
