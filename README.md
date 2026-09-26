# crd-ime-toggle

Chrome 원격 데스크톱(CRD)으로 맥에서 다른 맥에 접속했을 때, **로컬 캡스락 한 번으로 원격 맥의 한/영을 전환**한다.

## 왜 필요한가

캡스락으로 한영전환을 쓰는 맥(Karabiner로 캡스락 → F19, macOS "다음 입력 소스" 단축키 = F19)에서 CRD로 원격 맥에 접속하면:

- 캡스락을 누르면 **로컬 macOS가 F19를 먼저 가져가서** 로컬 입력 소스만 바뀐다
- 원격에는 키가 가지 않거나, 길게 눌렀을 때만 가끔 전달된다
- 원격 Karabiner는 CRD가 넣어 주는 키를 보지 못해서 원격 쪽 캡스락 매핑도 소용없다

결국 원격 작업 중 한영전환을 하려면 원격 메뉴바를 마우스로 눌러야 한다.

## 어떻게 동작하나

```
로컬 맥 (접속하는 쪽)                              원격 맥 (접속 당하는 쪽)
캡스락 -> F19
  CRD 앱이 맨 앞이면 F18로 바꿈 (Karabiner) ---CRD---> crd-ime-toggle 이 F18을 받아
  그 밖의 앱이면 F19 그대로 (로컬 한영전환)             원격의 한영전환 단축키를 대신 눌러 토글
```

- **로컬**: Karabiner 규칙 하나. CRD 앱 창에서만 캡스락을 F18로 바꾼다. F18은 macOS가 쓰지 않는 키라 CRD로 그대로 넘어간다
- **원격**: 상주 프로그램 `crd-ime-toggle`. CRD 호스트가 주입한 F18만 받아서, 원격 맥의 한영전환 단축키를 실제 키 입력처럼 눌러 준다. 원격 맥 앞에서 캡스락을 누른 것과 같은 경로라 앱에 즉시 반영된다
- **양방향**: 두 맥 모두에 둘 다 설치하면 A → B, B → A 모두 된다. 원격 프로그램은 CRD가 넣은 키에만 반응하므로 같은 맥의 로컬 규칙과 충돌하지 않는다
- 각 맥 앞에서 직접 캡스락을 누를 때의 동작은 바뀌지 않는다

## 요구 사항

- 양쪽 모두 macOS 13 이상
- 원격 맥: Swift 툴체인 (`xcode-select --install`)
- 로컬 맥: [Karabiner-Elements](https://karabiner-elements.pqrs.org)
- CRD는 **앱으로 설치해서** 사용. 일반 크롬 탭에서는 동작하지 않는다
  (크롬에서 `remotedesktop.google.com/access` 열기 → `⋮` > 전송, 저장, 공유 > 페이지를 앱으로 설치)

## 설치

### AI 에이전트에게 맡기기

에이전트(Claude Code 등)에게 아래처럼 요청하면 된다. 권한 허용 같은 사람이 해야 하는 단계는 에이전트가 알려 준다.

> https://github.com/imkdw/macos-han-young 를 clone 하고 INSTALL_FOR_AGENT.md 를 따라 설치해줘.

### 직접 설치

```bash
git clone https://github.com/imkdw/macos-han-young.git ~/macos-han-young
cd ~/macos-han-young
make doctor          # 이 맥이 로컬/원격 중 무엇인지, 무엇이 빠졌는지 점검
```

**원격 맥** (접속 당하는 쪽):

1. `make install`
2. 자동으로 열리는 시스템 설정 > 손쉬운 사용 에서 `crd-ime-toggle` 켜기. 켜는 즉시 동작하고, 로그인할 때마다 자동 실행된다

**로컬 맥** (접속하는 쪽):

1. `make karabiner-enable` (기존 `karabiner.json` 을 백업한 뒤 규칙을 켠다)
2. CRD를 앱으로 설치해서 그 창으로 접속

양방향으로 쓰려면 두 맥 모두에서 위 두 절차를 다 한다.

**캡스락 한영전환을 아직 안 쓰고 있다면** (선택):

```bash
make hotkey          # "입력 메뉴에서 다음 소스 선택" 단축키를 F19로 등록
```

`make karabiner-enable` 은 캡스락 → F19 매핑이 없으면 그것도 함께 추가한다.

### 입력 소스가 기본값과 다르면

기본값은 `com.apple.keylayout.ABC` 와 `com.apple.inputmethod.Korean.2SetKorean` 이다.

```bash
swift build -c release && .build/release/crd-ime-toggle --list      # 사용 가능한 ID 확인
make install ARGS="--en com.apple.keylayout.US --ko com.apple.inputmethod.Korean.3SetKorean"
```

## 확인

CRD 앱 창에서 캡스락을 누르고 원격 로그를 본다.

```bash
tail -f ~/Library/Logs/crd-ime-toggle.log
```

```
[...] com.apple.inputmethod.Korean.2SetKorean -> com.apple.keylayout.ABC (hotkey)
```

누를 때마다 한 줄씩 찍히면 정상이다. 안 될 때는 `make doctor` 를 먼저 실행하고,
증상별 원인과 조치는 [`INSTALL_FOR_AGENT.md`](INSTALL_FOR_AGENT.md) 의 문제 해결 표를 본다.

## 옵션

`make install ARGS="..."` 로 넘긴다.

| 옵션 | 기본값 | 설명 |
|---|---|---|
| `--en <id>`, `--ko <id>` | ABC, 2SetKorean | 토글할 두 입력 소스 |
| `--method <m>` | `auto` | `hotkey`: 한영전환 단축키를 대신 누름, `tis`: 입력 소스를 직접 선택 (가끔 앱 반영 누락), `auto`: 단축키가 있으면 hotkey |
| `--keycode <n>` | 79 (F18) | 트리거 키 |
| `--crd-keycode <n>` | 80 (F19) | 보조 트리거 키 (로컬 규칙 없이 길게 누른 F19가 넘어오는 경우) |
| `--debounce <ms>` | 300 | CRD가 한 번 누름에 keyDown을 여러 번 보낼 때 한 번으로 묶는 시간 |
| `--crd-process <name>` | `remoting_me2me_host` | 키를 주입하는 CRD 호스트 프로세스 이름 |

진단용: `--list` (입력 소스 목록), `--current` (현재 입력 소스), `--toggle` (한 번 토글), `--check` (설정 확인)

## 제거

```bash
make uninstall                                     # 원격 프로그램 제거
ls ~/.config/karabiner/karabiner.json.bak-*-before-crd-ime-toggle   # 로컬: 이 백업으로 되돌리기
```

손쉬운 사용 목록에 남은 `crd-ime-toggle` 항목은 시스템 설정에서 지운다.

## 개발

```bash
make test        # 단위 테스트
make e2e         # 데몬을 띄우고 합성 키를 주입해 토글 확인 (터미널 앱에 손쉬운 사용 권한 필요)
make keylog      # 키 입력 기록기. 어떤 키가 어디서 들어오는지 볼 때 사용 (끝나면 ~/keylog-*.txt 삭제)
```

배경과 요구사항은 [`docs/PRD.md`](docs/PRD.md), 초기 구현 계획은 [`docs/PLAN.md`](docs/PLAN.md) 에 있다.
