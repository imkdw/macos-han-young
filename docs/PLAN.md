# 구현 계획: crd-ime-toggle

PRD: `docs/PRD.md`. 총 예상 시간은 약 1시간 30분이다. (원격 수동 테스트 포함)

## 산출물 구조

```
~/crd-ime-toggle/
  Package.swift
  Sources/crd-ime-toggle/main.swift   # 이벤트 탭 + TIS 토글
  Sources/keylog/main.swift           # Phase 0 스파이크용 keycode 로거
  launchd/com.imkdw.crd-ime-toggle.plist
  scripts/install.sh                  # 빌드, ~/.local/bin 복사, launchctl bootstrap
  scripts/uninstall.sh
  karabiner/crd-f19-to-f18.json       # 로컬 규칙 백업본 (재설치용)
  docs/PRD.md, docs/PLAN.md
```

## Phase 0: 스파이크 (15분, 원격에서 확인)

R1, R2를 먼저 없앤다. 여기서 막히면 뒤 단계로 진행하지 않는다.

1. `keylog` 작성: 세션 이벤트 탭으로 keyDown/flagsChanged의 keycode를 stdout에 출력
2. 원격에서 `swift run keylog` 실행 후 손쉬운 사용 권한 허용
3. 로컬 CRD 창에서 캡스락 누름 → 원격 로그에 `79`(F18)가 찍히는지 확인
- 찍힘: Phase 1 진행
- 안 찍힘: 로컬 규칙의 출력 키를 `ctrl+option+space` 같은 조합으로 바꿔 다시 시도하고, 트리거 키 설정을 조합 키까지 받을 수 있게 F2를 넓힌다

## Phase 1: 토글 코어 (20분)

1. `InputSource` 모듈
   - `TISCreateInputSourceList` 로 ID를 입력 소스 객체로 찾는다
   - `TISCopyCurrentKeyboardInputSource` 로 현재 ID를 확인한다
   - 현재가 한글이면 영문, 그 밖에는 한글을 `TISSelectInputSource` 로 선택한다 (S5 충족)
2. 설정: 실행 인자 `--en <id> --ko <id> --keycode <n>`. 기본값은 PRD F3와 79
3. 시작할 때 두 ID를 찾지 못하면 활성 입력 소스 목록을 출력하고 exit 1

## Phase 2: 이벤트 탭 (20분)

1. `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: keyDown|keyUp)`
2. 콜백
   - keycode가 설정값이고 `keyboardEventAutorepeat == 0` 인 keyDown이면 토글하고 `nil` 반환 (이벤트 삼킴)
   - 같은 keycode의 keyUp도 `nil` 반환
   - `tapDisabledByTimeout` 또는 `tapDisabledByUserInput` 이면 `CGEvent.tapEnable(true)` 로 다시 켠다 (F5)
3. 시작할 때 `AXIsProcessTrustedWithOptions(prompt: true)` 로 권한을 확인하고, 없으면 안내를 출력한 뒤 exit 1
4. `CFRunLoopRun()` 으로 상주

## Phase 3: 배포 (15분)

1. `swift build -c release` 뒤 결과물을 `~/.local/bin/crd-ime-toggle` 로 복사하고 ad-hoc 서명 (`codesign -s -`)
2. LaunchAgent plist: `RunAtLoad=true`, `KeepAlive=true`, 로그는 `~/Library/Logs/crd-ime-toggle.log`
3. `install.sh`: 빌드, 복사, 서명, `launchctl bootstrap gui/$UID`, 권한 안내 출력
4. `uninstall.sh`: `launchctl bootout`, 파일 삭제

권한 주의: 손쉬운 사용 권한은 바이너리 경로와 서명에 묶인다. 재빌드하면 권한 목록에서 한 번 지우고 다시 허용해야 할 수 있다.

## Phase 4: 검증 (15분, 원격에서 수동)

PRD 4장의 S1~S5를 순서대로 확인한다.

| 시나리오 | 확인 방법 |
|---|---|
| S1 | CRD 창에서 캡스락 10회, 원격 메뉴바 아이콘이 매번 바뀌고 로컬은 그대로 |
| S2 | 로컬 메모장에서 캡스락, 로컬만 바뀜 |
| S3 | 원격 물리 키보드 캡스락, 한 번만 바뀜 |
| S4 | 원격 로그아웃 후 로그인, `launchctl print gui/$UID/com.imkdw.crd-ime-toggle` 가 running |
| S5 | 원격에서 세 번째 입력 소스 선택 후 S1, 영문으로 바뀜 |

## 로컬 쪽 현황

- Karabiner 규칙 "Chrome 원격 데스크톱: 캡스락(F19) -> F18" 은 이미 `~/.config/karabiner/karabiner.json` 에 있다. 백업은 `karabiner.json.bak-before-crd-f18`
- Phase 3에서 같은 규칙을 `karabiner/crd-f19-to-f18.json` 으로 저장소에 복사해 둔다
