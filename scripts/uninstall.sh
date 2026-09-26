#!/bin/bash
# 원격 맥에서 제거: LaunchAgent 해제, 파일 삭제
set -euo pipefail

LABEL="com.imkdw.crd-ime-toggle"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST" "$BIN_DIR/crd-ime-toggle" "$BIN_DIR/crd-ime-toggle.unsigned"

echo "제거 완료"
echo "손쉬운 사용 목록에 남은 crd-ime-toggle 항목은 시스템 설정에서 직접 지우세요."
echo "로그를 지우려면: rm ~/Library/Logs/crd-ime-toggle.log"
