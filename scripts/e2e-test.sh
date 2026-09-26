#!/bin/bash
# 이벤트 탭 end-to-end 테스트: 데몬을 띄우고 합성 F18을 주입해 토글 횟수를 확인한다
# 실행하는 터미널 앱에 손쉬운 사용 권한이 있어야 한다. 끝나면 입력 소스를 원래대로 되돌린다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build --product crd-ime-toggle >/dev/null
BIN="$(swift build --show-bin-path)/crd-ime-toggle"
SEND=".build/send-key"
swiftc -O scripts/send-key.swift -o "$SEND"

LOG="$(mktemp -t crd-ime-e2e)"
ORIGINAL="$("$BIN" --current)"

"$BIN" >"$LOG" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
sleep 1.5

if ! grep -q "시작:" "$LOG"; then
    echo "FAIL: 데몬이 시작되지 않음 (터미널 앱의 손쉬운 사용 권한 확인)"
    cat "$LOG"
    exit 1
fi

"$SEND" 79; sleep 0.4          # 토글 1
"$SEND" 79; sleep 0.4          # 토글 2
"$SEND" 79 repeat; sleep 0.4   # autorepeat: 무시 (F4)
"$SEND" 80 >/dev/null 2>&1 || true; sleep 0.4   # F19: 데몬은 무시 (S3). 시스템 단축키가 한 번 토글할 수 있음

kill $PID; wait $PID 2>/dev/null || true; trap - EXIT
TOGGLES="$(grep -c -- ' -> ' "$LOG" || true)"
cat "$LOG"
rm -f "$LOG"

# F19 시스템 단축키 토글분까지 되돌린다
for _ in 1 2; do
    [[ "$("$BIN" --current)" == "$ORIGINAL" ]] && break
    "$BIN" --toggle >/dev/null
done

if [[ "$TOGGLES" == 2 ]]; then
    echo "PASS: F18 2회 -> 토글 2회, autorepeat 무시, F19 무시"
else
    echo "FAIL: 토글 $TOGGLES 회 (기대값 2)"
    exit 1
fi
