# crd-ime-toggle 설치 가이드 (AI 에이전트용)

이 문서는 사람이 AI 코딩 에이전트(Claude Code 등)에게 그대로 넘겨서 설치를 맡기기 위한 문서다.
에이전트는 위에서부터 순서대로 실행하고, **[사람]** 표시가 있는 단계에서만 사용자에게 요청한다.

사용자가 에이전트에게 줄 문장 예시:

> https://github.com/imkdw/macos-han-young 를 clone 하고 INSTALL_FOR_AGENT.md 를 따라 설치해줘.

## 0. 무엇을 설치하는가

Chrome 원격 데스크톱(CRD)으로 맥에서 맥에 접속했을 때, 로컬 캡스락 한 번으로 **원격 맥**의 한/영을 바꾼다.

```
로컬 맥 (접속하는 쪽)                           원격 맥 (CRD 호스트)
캡스락 -> [Karabiner] F19                          crd-ime-toggle (LaunchAgent)
  CRD 앱이 맨 앞이면 -> [Karabiner 규칙] F18  ---CRD--->  CRD 호스트가 주입한 F18만 받아 시스템 한영전환 단축키를 대신 눌러 토글
  그 밖의 앱이면 F19 그대로 -> 로컬 한영전환
```

- 로컬 맥: Karabiner 규칙 하나 (`karabiner/crd-f19-to-f18.json`)
- 원격 맥: Swift로 빌드한 상주 프로그램 하나 (`make install`)
- **양방향(A -> B, B -> A)으로 쓰려면 두 맥 모두에 2단계와 3단계를 전부 한다.** 충돌하지 않는다
  - 원격 프로그램은 CRD 호스트 프로세스(`remoting_me2me_host`)가 주입한 키에만 반응한다
  - 그래서 A에서 B를 조작할 때 A의 Karabiner가 만든 F18은 A의 원격 프로그램을 그냥 지나쳐 CRD로 넘어가고, B의 원격 프로그램만 토글한다
  - 각 맥 앞에서 직접 캡스락을 누르면 CRD 앱이 맨 앞이 아니므로 F19 그대로, 평소처럼 로컬 한영전환이 된다

### 에이전트가 알아야 할 제약

- 원격 프로그램은 **손쉬운 사용(Accessibility) 권한**이 있어야 동작한다. 권한은 사람만 켤 수 있다
- 로컬 규칙은 CRD가 **설치된 앱**(`com.google.Chrome.app.cmkncekebbebpfilplodngbpllndjkfo`)으로 열려 있을 때만 적용된다. 일반 크롬 탭(`com.google.Chrome`)에서는 동작하지 않는다
- 키 입력 테스트는 사람이 로컬 키보드로 해야 한다. 에이전트는 원격 로그로 결과를 확인한다
- 에이전트가 원격 맥에서 실행 중이라면 로컬 맥 설정은 건드릴 수 없다. 로컬 절차는 사용자에게 로컬 터미널에서 직접 실행하도록 안내한다

## 1. 준비

```bash
git clone https://github.com/imkdw/macos-han-young.git ~/macos-han-young
cd ~/macos-han-young
make doctor
```

`make doctor` 는 이 맥이 원격(CRD 호스트)인지 판별하고, 각 항목을 `OK` / `WARN` / `FAIL` 로 출력한다.
이후 단계는 `WARN`, `FAIL` 항목만 처리하면 된다.

| doctor 출력 | 처리 |
|---|---|
| `FAIL swift 없음` | **[사람]** `xcode-select --install` 설치 창 승인 |
| `WARN 입력 소스 전환 단축키 없음` | `make hotkey` (원격은 이 단축키를 대신 눌러 토글한다. 없으면 정확도가 낮은 tis 방식으로 동작) |
| `WARN Karabiner-Elements 설정 없음` | 로컬 맥이라면 **[사람]** https://karabiner-elements.pqrs.org 설치 후 한 번 실행하고 권한 허용 |
| `WARN Karabiner 캡스락 -> F19 매핑 없음` | 로컬: 3단계의 `make karabiner-enable` 이 함께 추가한다. 원격 맥 앞에서도 캡스락 한영전환을 쓰려면 원격에도 같은 매핑 필요 |

## 2. 원격 맥 (CRD 호스트)

doctor 출력에 `== 원격 (CRD 호스트 설치됨)` 이 있으면 이 단계를 한다. 양방향이면 두 맥 모두 한다.

```bash
make install
```

- 입력 소스 ID가 기본값(`com.apple.keylayout.ABC`, `com.apple.inputmethod.Korean.2SetKorean`)과 다르면 설치 전에 확인한다:
  ```bash
  swift build -c release && .build/release/crd-ime-toggle --list
  make install ARGS="--en <영문 ID> --ko <한글 ID>"
  ```
- 설치 스크립트가 `--check` 로 설정을 먼저 검증하므로, 실패하면 출력된 입력 소스 목록을 보고 ARGS를 고친다

**[사람]** 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 에서 `crd-ime-toggle` 을 켜 달라고 요청한다. 설치 스크립트가 해당 화면을 연다.
목록에 예전 `crd-ime-toggle` 항목이 있으면 `-` 로 지우고 다시 추가해야 한다(재빌드하면 서명이 바뀐다).
권한을 켜면 재설치 없이 바로 동작한다.

확인:

```bash
make doctor   # "OK 데몬 시작됨: 시작: ... method=hotkey(keycode=80) ..." 가 보여야 한다
```

`FAIL 손쉬운 사용 권한 대기 중` 이면 사용자가 아직 권한을 켜지 않은 것이다.

## 3. 로컬 맥 (CRD로 접속하는 쪽)

이 맥에서 다른 맥으로 CRD 접속을 한다면 이 단계를 한다. 양방향이면 두 맥 모두 한다.

```bash
make karabiner-enable
```

- `~/.config/karabiner/karabiner.json` 을 `karabiner.json.bak-<시각>-before-crd-ime-toggle` 로 백업한 뒤, 선택된 프로필 맨 앞에 CRD 규칙을 넣는다
- 캡스락 -> F19 매핑이 없으면 그것도 함께 넣는다
- 여러 번 실행해도 규칙이 중복되지 않는다
- 사용자의 키보드 설정을 바꾸는 작업이므로 실행 전에 사용자에게 한 번 알린다

**[사람]** CRD를 앱으로 설치해서 열어 달라고 요청한다. doctor가 `WARN CRD 앱 없음` 을 출력한 경우에만 필요하다.
1. 크롬에서 `https://remotedesktop.google.com/access` 열기
2. 주소창 오른쪽 설치 아이콘, 또는 `⋮` > 전송, 저장, 공유 > 페이지를 앱으로 설치
3. 이후 원격 접속은 항상 이 앱 창에서 한다

## 4. 동작 확인

**[사람]** CRD 앱 창에서 원격 맥의 입력칸을 클릭하고, 캡스락을 짧게 누른 뒤 글자를 입력하는 것을 5번 반복해 달라고 요청한다.

에이전트는 원격 맥에서 로그를 본다:

```bash
tail -20 ~/Library/Logs/crd-ime-toggle.log
```

정상이라면 누를 때마다 한 줄씩 찍힌다:

```
[...] com.apple.inputmethod.Korean.2SetKorean -> com.apple.keylayout.ABC (hotkey)
[...] com.apple.keylayout.ABC -> com.apple.inputmethod.Korean.2SetKorean (hotkey)
```

## 5. 문제 해결

실제로 겪은 증상과 원인이다. 위에서부터 확인한다.

| 증상 | 원인 | 조치 |
|---|---|---|
| 원격 로그에 아무것도 안 찍힘 | 로컬에서 CRD를 크롬 탭으로 열었거나 로컬 규칙이 없음. 로컬 macOS가 F19를 한영전환으로 먼저 소비해 원격에 안 감 | 로컬에서 `sleep 5; lsappinfo info -only bundleid "$(lsappinfo front)"` 실행 후 5초 안에 CRD 창 클릭. `com.google.Chrome` 이면 3단계의 앱 설치 |
| 캡스락을 **길게** 눌러야만 가끔 바뀜 | 위와 같음. 길게 누르면 CRD가 F19를 반복 전송해 일부가 원격에 도착한다. 원격 프로그램이 CRD가 보낸 F19도 받아 주지만 짧은 누름은 로컬이 가져간다 | 위와 같음 |
| 로그에는 토글이 찍히는데 입력되는 글자가 가끔 이전 언어 | `(tis)` 방식으로 동작 중. macOS가 백그라운드 입력 소스 변경을 앱에 늦게 반영함 | `make hotkey` 로 단축키 등록 후 `make install` 재실행. 로그가 `(hotkey)` 로 바뀌어야 한다 |
| doctor `FAIL 손쉬운 사용 권한 대기 중` | 권한 없음 | 2단계의 [사람] 요청 |
| `입력 소스를 찾지 못했습니다` (exit 78) | 입력 소스 ID 불일치 | `--list` 결과로 `make install ARGS=...` |

키가 실제로 어떻게 들어오는지 봐야 할 때:

```bash
swift run keylog   # 원격 또는 로컬에서 실행. HID/session 단계별 keycode, 보낸 프로세스, 맨 앞 앱을 출력
```

- 원격에서 CRD가 보낸 키는 `src=...:remoting_me2me_host` 로 보이고 session 단계에만 찍힌다
- 로컬에서 CRD 앱이 맨 앞이면 CRD가 키보드를 가져가서 keylog에 아무것도 안 찍힐 수 있다. 이는 정상이다
- keylog는 모든 키 입력을 `~/keylog-<호스트명>.txt` 에 기록한다. **확인이 끝나면 반드시 종료하고 이 파일을 지운다**

## 6. 제거

```bash
make uninstall                                                     # 원격
cp ~/.config/karabiner/karabiner.json.bak-*-before-crd-ime-toggle ~/.config/karabiner/karabiner.json   # 로컬, 백업 복원
```

손쉬운 사용 목록에 남은 `crd-ime-toggle` 항목은 사용자가 시스템 설정에서 지운다.
