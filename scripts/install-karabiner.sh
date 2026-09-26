#!/bin/bash
# 로컬 맥(CRD로 접속하는 쪽)에 Karabiner 규칙 파일을 넣는다
# 규칙을 켜는 것은 Karabiner-Elements 설정 화면에서 직접 한다
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.config/karabiner/assets/complex_modifications"

if [[ ! -d "$HOME/.config/karabiner" ]]; then
    echo "Karabiner-Elements가 설치되어 있지 않습니다. https://karabiner-elements.pqrs.org 에서 먼저 설치하세요." >&2
    exit 1
fi

mkdir -p "$DEST"
cp "$ROOT/karabiner/crd-f19-to-f18.json" "$DEST/crd-ime-toggle.json"

echo "규칙 파일 복사 완료: $DEST/crd-ime-toggle.json"
echo
echo "다음 단계:"
echo "  1. Karabiner-Elements 설정 > Complex Modifications > Add predefined rule"
echo "  2. 'crd-ime-toggle' 항목에서 'Chrome 원격 데스크톱: 캡스락(F19) -> F18' 을 Enable"
echo "  3. 캡스락 -> F19 매핑이 아직 없다면 '캡스락 -> F19' 도 Enable (CRD 규칙보다 아래에 두기)"
open -a "Karabiner-Elements" 2>/dev/null || true
