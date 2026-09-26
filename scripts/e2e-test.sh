#!/bin/bash
# 이벤트 탭 end-to-end 테스트: 데몬을 띄우고 합성 키를 주입해 토글 횟수를 확인한다
# 실행하는 터미널 앱에 손쉬운 사용 권한이 있어야 한다. 끝나면 입력 소스를 원래대로 되돌린다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build --product crd-ime-toggle >/dev/null
BIN="$(swift build --show-bin-path)/crd-ime-toggle"
SEND=".build/send-key"
swiftc -O scripts/send-key.swift -o "$SEND"

ORIGINAL="$("$BIN" --current)"
LOG="$(mktemp -t crd-ime-e2e)"
PID=""
cleanup() {
    [[ -n "$PID" ]] && kill "$PID" 2>/dev/null && wait "$PID" 2>/dev/null
    rm -f "$LOG"
    for _ in 1 2; do
        [[ "$("$BIN" --current)" == "$ORIGINAL" ]] && break
        "$BIN" --toggle >/dev/null
    done
}
trap cleanup EXIT

# run <데몬 인자...>: 데몬을 띄운 뒤 run_keys 를 실행하고 토글 횟수를 TOGGLES 에 담는다
run() {
    : >"$LOG"
    "$BIN" "$@" >"$LOG" 2>&1 &
    PID=$!
    sleep 1.5
    if ! grep -q "시작:" "$LOG"; then
        echo "FAIL: 데몬이 시작되지 않음 (터미널 앱의 손쉬운 사용 권한 확인)"
        cat "$LOG"
        exit 1
    fi
    run_keys
    sleep 0.3
    kill "$PID"; wait "$PID" 2>/dev/null || true; PID=""
    TOGGLES="$(grep -c -- ' -> ' "$LOG" || true)"
}

FAILED=0
check() {
    if [[ "$2" == "$3" ]]; then echo "PASS: $1"; else echo "FAIL: $1 (토글 $2 회, 기대값 $3)"; cat "$LOG"; FAILED=1; fi
}

# 1) 이 맥의 키보드에서 온 F18은 통과 (양방향 설치 시 로컬 F18이 CRD로 넘어가야 함)
run_keys() { "$SEND" 79; sleep 0.4; "$SEND" 79; sleep 0.4; }
run
check "로컬 F18 통과" "$TOGGLES" 0

# 2) CRD 호스트가 보낸 F18은 토글, autorepeat 무시. send-key 를 CRD 호스트로 간주한다
run_keys() { "$SEND" 79; sleep 0.8; "$SEND" 79; sleep 0.8; "$SEND" 79 repeat; sleep 0.4; }
run --crd-process send-key
check "CRD F18 토글 2회, autorepeat 무시" "$TOGGLES" 2

exit "$FAILED"
