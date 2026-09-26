# crd-ime-toggle

Chrome 원격 데스크톱(CRD)으로 맥에서 맥으로 접속했을 때, 로컬 캡스락 한 번으로 **원격 맥**의 한/영을 전환한다.

- 로컬 맥: Karabiner가 CRD 앱 창에서만 캡스락(F19)을 F18로 바꾼다
- 원격 맥: `crd-ime-toggle` 이 F18을 받아 한/영 입력 소스를 토글한다 (LaunchAgent로 상주)

배경과 요구사항은 [`docs/PRD.md`](docs/PRD.md), 구현 계획은 [`docs/PLAN.md`](docs/PLAN.md) 참고.

## 요구 사항

- macOS 13 이상, 로컬과 원격 모두 맥
- 원격 맥: Swift 툴체인 (`xcode-select --install`)
- 로컬 맥: [Karabiner-Elements](https://karabiner-elements.pqrs.org)
- CRD는 **앱으로 설치해서** 사용 (크롬 탭에서 여는 경우는 지원하지 않음)
- 캡스락으로 한영전환하는 기존 설정 (캡스락 → F19, "입력 메뉴에서 다음 소스 선택" 단축키 = F19). 없다면 아래 3단계 참고

## 설치

```bash
git clone <이 저장소> && cd macos-han-young
```

### 1. 원격 맥 (접속 당하는 쪽)

```bash
make install
```

1. 빌드 후 `~/.local/bin/crd-ime-toggle` 에 설치하고 로그인 시 자동 실행되도록 LaunchAgent를 등록한다
2. 시스템 설정의 손쉬운 사용 화면이 열리면 `crd-ime-toggle` 을 켠다. 재설치 없이 바로 동작한다

입력 소스가 기본값(`com.apple.keylayout.ABC`, `com.apple.inputmethod.Korean.2SetKorean`)과 다르면:

```bash
.build/release/crd-ime-toggle --list          # 사용 가능한 ID 확인
make install ARGS="--en com.apple.keylayout.US --ko com.apple.inputmethod.Korean.3SetKorean"
```

### 2. 로컬 맥 (접속하는 쪽)

```bash
make karabiner
```

Karabiner-Elements 설정 > Complex Modifications > Add predefined rule 에서
`Chrome 원격 데스크톱: 캡스락(F19) -> F18` 을 Enable 한다.

### 3. (선택) 캡스락 한영전환이 아직 없다면

로컬과 원격 **둘 다** 에서:

```bash
make hotkey      # "입력 메뉴에서 다음 소스 선택" 단축키를 F19로 등록
```

- 로컬: `make karabiner` 로 넣은 규칙 중 `캡스락 -> F19` 도 Enable
- 원격: Karabiner에서 캡스락 → F19 매핑 (Simple Modifications)

## 확인

```bash
tail -f ~/Library/Logs/crd-ime-toggle.log                       # 원격: 토글할 때마다 한 줄씩 찍힘
launchctl print gui/$(id -u)/com.imkdw.crd-ime-toggle | grep state   # running 이어야 함
```

CRD 창에서 캡스락을 누르면 로그에 `com.apple.keylayout.ABC -> com.apple.inputmethod.Korean.2SetKorean` 같은 줄이 찍힌다.

### 안 될 때

| 증상 | 확인 |
|---|---|
| 로그에 "권한이 허용될 때까지 기다립니다" | 손쉬운 사용에서 `crd-ime-toggle` 켜기. 재빌드 뒤라면 기존 항목을 `-` 로 지우고 다시 추가 |
| 로그에 아무것도 안 찍힘 | 원격에서 `make keylog` 실행 후 CRD 창에서 캡스락. `keycode=79` 가 안 보이면 로컬 Karabiner 규칙 확인 |
| "입력 소스를 찾지 못했습니다" | `--list` 로 ID 확인 후 `make install ARGS=...` |

## 개발

```bash
make test        # 단위 테스트
make e2e         # 데몬을 띄우고 합성 F18을 주입해 토글 확인 (터미널 앱에 손쉬운 사용 권한 필요)
make keylog      # keycode 로거 (Phase 0 스파이크)
```

`crd-ime-toggle` 옵션:

```
--en <id>        영문 입력 소스 ID
--ko <id>        한글 입력 소스 ID
--keycode <n>    트리거 keycode (기본값 79, F18)
--toggle         한 번만 토글하고 종료
--check          설정만 확인하고 종료
--list           선택 가능한 입력 소스 ID 목록
--current        현재 입력 소스 ID
```

## 제거

```bash
make uninstall                       # 원격
rm ~/.config/karabiner/assets/complex_modifications/crd-ime-toggle.json   # 로컬 (규칙도 Karabiner에서 Remove)
```
