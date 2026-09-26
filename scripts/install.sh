#!/bin/bash
# 원격 맥에 설치: 빌드, ~/.local/bin 복사, ad-hoc 서명, LaunchAgent 등록
# 사용법: ./scripts/install.sh [crd-ime-toggle 옵션...]
#   예) ./scripts/install.sh --ko com.apple.inputmethod.Korean.3SetKorean
set -euo pipefail

LABEL="com.imkdw.crd-ime-toggle"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
BIN="$BIN_DIR/crd-ime-toggle"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/crd-ime-toggle.log"
DOMAIN="gui/$(id -u)"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "macOS에서만 설치할 수 있습니다." >&2
    exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
    echo "swift가 없습니다. 먼저 'xcode-select --install' 로 Command Line Tools를 설치하세요." >&2
    exit 1
fi

echo "==> 빌드"
swift build -c release --package-path "$ROOT" --product crd-ime-toggle
BUILT="$(swift build -c release --package-path "$ROOT" --show-bin-path)/crd-ime-toggle"

echo "==> 설정 확인"
"$BUILT" --check "$@"

# 손쉬운 사용 권한은 바이너리 서명(cdhash)에 묶인다. 내용이 같으면 덮어쓰지 않아 권한을 유지한다.
mkdir -p "$BIN_DIR"
BINARY_CHANGED=0
if [[ -f "$BIN" ]] && cmp -s "$BUILT" "$BIN.unsigned" 2>/dev/null; then
    echo "==> 바이너리 변경 없음, 복사 생략"
else
    echo "==> $BIN 복사 및 서명"
    cp "$BUILT" "$BIN.unsigned"
    cp "$BUILT" "$BIN"
    codesign --force --sign - --identifier "$LABEL" "$BIN"
    BINARY_CHANGED=1
fi

echo "==> LaunchAgent 등록"
mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
sed -e "s|__BIN__|$BIN|" -e "s|__LOG__|$LOG|g" "$ROOT/launchd/$LABEL.plist" > "$PLIST"
for arg in "$@"; do
    /usr/libexec/PlistBuddy -c "Add :ProgramArguments: string $arg" "$PLIST"
done
plutil -lint -s "$PLIST"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"

echo
echo "설치 완료"
echo "  바이너리: $BIN"
echo "  LaunchAgent: $PLIST"
echo "  로그: $LOG"
echo
if [[ "$BINARY_CHANGED" == 1 ]]; then
    echo "!! 손쉬운 사용 권한을 허용해야 동작합니다."
    echo "   시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 에서 crd-ime-toggle 을 켜세요."
    echo "   목록에 이전 crd-ime-toggle 항목이 있으면 '-' 로 지운 뒤 다시 허용하세요. (재빌드하면 서명이 바뀌어 권한이 풀립니다)"
    echo "   권한을 켜면 재설치 없이 바로 동작합니다. 로그: tail -f $LOG"
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
fi
