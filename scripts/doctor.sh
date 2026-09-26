#!/bin/bash
# 설치 상태 점검. 로컬(CRD 접속하는 쪽), 원격(CRD 호스트) 역할을 자동으로 판별해 필요한 항목만 본다
# 각 줄은 OK / WARN / FAIL 로 시작한다. 에이전트가 읽기 쉽도록 형식을 유지할 것
set -uo pipefail

LABEL="com.imkdw.crd-ime-toggle"
CRD_APP_ID="com.google.Chrome.app.cmkncekebbebpfilplodngbpllndjkfo"
LOG="$HOME/Library/Logs/crd-ime-toggle.log"
KARABINER_JSON="$HOME/.config/karabiner/karabiner.json"

ok()   { echo "OK   $*"; }
warn() { echo "WARN $*"; }
fail() { echo "FAIL $*"; }

echo "== 공통"
ok "macOS $(sw_vers -productVersion)"
if command -v swift >/dev/null 2>&1; then ok "swift 있음"; else fail "swift 없음: xcode-select --install"; fi

# 입력 소스 전환 단축키 (61 다음 소스, 60 이전 소스)
HOTKEY="$(python3 - <<'PY' 2>/dev/null
import plistlib, subprocess
raw = subprocess.run(["defaults", "export", "com.apple.symbolichotkeys", "-"], capture_output=True).stdout
keys = plistlib.loads(raw).get("AppleSymbolicHotKeys", {}) if raw else {}
for k in ("61", "60"):
    e = keys.get(k) or {}
    p = (e.get("value") or {}).get("parameters") or []
    if e.get("enabled") and len(p) == 3 and p[1] != 65535:
        print(f"{k} keycode={p[1]} modifiers={p[2]}")
        break
PY
)"
if [[ -n "$HOTKEY" ]]; then
    ok "입력 소스 전환 단축키: $HOTKEY (keycode=80 이면 F19)"
else
    warn "입력 소스 전환 단축키 없음: make hotkey 로 F19 등록 권장 (없으면 원격은 tis 방식으로 동작)"
fi

if [[ -f "$KARABINER_JSON" ]]; then
    CAPS="$(python3 - "$KARABINER_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ps = d.get("profiles", [])
p = next((x for x in ps if x.get("selected")), ps[0] if ps else {})
def caps(ms): return any(m.get("from", {}).get("key_code") == "caps_lock" and any(t.get("key_code") == "f19" for t in m.get("to", [])) for m in ms)
rules = p.get("complex_modifications", {}).get("rules", [])
print("yes" if caps(p.get("simple_modifications", [])) or any(caps(r.get("manipulators", [])) for r in rules) else "no")
crd = [r for r in rules if any(c.get("type") == "frontmost_application_if" and any("cmkncekebbebpfilplodngbpllndjkfo" in b for b in c.get("bundle_identifiers", [])) for m in r.get("manipulators", []) for c in m.get("conditions", []))]
print("yes" if crd else "no")
PY
)"
    CAPS_F19="$(echo "$CAPS" | sed -n 1p)"
    CRD_RULE="$(echo "$CAPS" | sed -n 2p)"
    if [[ "$CAPS_F19" == yes ]]; then ok "Karabiner 캡스락 -> F19 매핑 있음"; else warn "Karabiner 캡스락 -> F19 매핑 없음"; fi
else
    CRD_RULE="no"
    warn "Karabiner-Elements 설정 없음 ($KARABINER_JSON)"
fi

IS_HOST=0
pgrep -f remoting_me2me_host >/dev/null 2>&1 && IS_HOST=1
[[ -d "/Library/PrivilegedHelperTools/ChromeRemoteDesktopHost.app" ]] && IS_HOST=1

echo
if [[ "$IS_HOST" == 1 ]]; then
    echo "== 원격 (CRD 호스트 설치됨)"
    if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
        STATE="$(launchctl print "gui/$(id -u)/$LABEL" | awk '/^\tstate =/{print $3; exit}')"
        if [[ "$STATE" == running ]]; then ok "LaunchAgent running"; else fail "LaunchAgent state=$STATE"; fi
    else
        fail "LaunchAgent 미설치: make install"
    fi
    if [[ -f "$LOG" ]]; then
        LAST_START="$(grep -E '시작:|권한이 필요' "$LOG" | tail -1)"
        case "$LAST_START" in
            *시작:*) ok "데몬 시작됨: ${LAST_START#*] }" ;;
            *권한*) fail "손쉬운 사용 권한 대기 중: 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 에서 crd-ime-toggle 켜기 (사람이 해야 함)" ;;
            *) warn "로그에 시작 기록 없음: $LOG" ;;
        esac
        LAST_TOGGLE="$(grep -- ' -> ' "$LOG" | tail -1)"
        [[ -n "$LAST_TOGGLE" ]] && ok "마지막 토글: $LAST_TOGGLE" || warn "아직 토글 기록 없음 (CRD 창에서 캡스락을 눌러 확인)"
    else
        warn "로그 없음: $LOG"
    fi
else
    echo "== 원격: 이 맥에는 CRD 호스트가 없어 건너뜀"
fi

echo
echo "== 로컬 (CRD로 접속하는 쪽)"
if mdfind "kMDItemCFBundleIdentifier == '$CRD_APP_ID'" 2>/dev/null | grep -q .; then
    ok "CRD 앱 설치됨 ($CRD_APP_ID)"
else
    warn "CRD 앱 없음: 크롬에서 remotedesktop.google.com/access 를 열고 '페이지를 앱으로 설치' (크롬 탭에서는 동작하지 않음, 사람이 해야 함)"
fi
if [[ "$CRD_RULE" == yes ]]; then
    ok "Karabiner CRD 규칙(F19 -> F18) 켜짐"
else
    warn "Karabiner CRD 규칙 없음: ./scripts/install-karabiner.sh --enable (이 맥에서 CRD로 접속한다면 필요)"
fi
