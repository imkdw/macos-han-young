#!/bin/bash
# 로컬 맥(CRD로 접속하는 쪽)에 Karabiner 규칙을 넣는다
# 사용법:
#   ./scripts/install-karabiner.sh           규칙 파일만 복사 (Karabiner 설정 화면에서 직접 Enable)
#   ./scripts/install-karabiner.sh --enable  karabiner.json 을 백업한 뒤 선택된 프로필에 규칙을 바로 켠다
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KARABINER_DIR="$HOME/.config/karabiner"
DEST="$KARABINER_DIR/assets/complex_modifications"
RULES="$ROOT/karabiner/crd-f19-to-f18.json"

if [[ ! -d "$KARABINER_DIR" ]]; then
    echo "Karabiner-Elements가 설치되어 있지 않습니다. https://karabiner-elements.pqrs.org 에서 먼저 설치하세요." >&2
    exit 1
fi

mkdir -p "$DEST"
cp "$RULES" "$DEST/crd-ime-toggle.json"
echo "규칙 파일 복사 완료: $DEST/crd-ime-toggle.json"

if [[ "${1:-}" != "--enable" ]]; then
    echo
    echo "다음 단계:"
    echo "  1. Karabiner-Elements 설정 > Complex Modifications > Add predefined rule"
    echo "  2. 'crd-ime-toggle' 항목에서 'Chrome 원격 데스크톱: 캡스락(F19) -> F18' 을 Enable"
    echo "  3. 캡스락 -> F19 매핑이 아직 없다면 '캡스락 -> F19' 도 Enable (CRD 규칙보다 아래에 두기)"
    echo "  (또는 ./scripts/install-karabiner.sh --enable 로 바로 적용)"
    open -a "Karabiner-Elements" 2>/dev/null || true
    exit 0
fi

CONFIG="$KARABINER_DIR/karabiner.json"
if [[ ! -f "$CONFIG" ]]; then
    echo "$CONFIG 가 없습니다. Karabiner-Elements를 한 번 실행한 뒤 다시 시도하세요." >&2
    exit 1
fi

BACKUP="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)-before-crd-ime-toggle"
cp "$CONFIG" "$BACKUP"
echo "백업: $BACKUP"

# 선택된 프로필의 complex_modifications 맨 앞에 CRD 규칙을 넣는다 (같은 설명의 규칙이 있으면 교체)
# 캡스락 -> F19 매핑이 simple/complex 어디에도 없으면 캡스락 -> F19 규칙도 CRD 규칙 뒤에 넣는다
python3 - "$CONFIG" "$RULES" <<'EOF'
import json, sys

config_path, rules_path = sys.argv[1], sys.argv[2]
config = json.load(open(config_path))
crd_rule, caps_rule = json.load(open(rules_path))["rules"]

profiles = config.get("profiles", [])
profile = next((p for p in profiles if p.get("selected")), profiles[0] if profiles else None)
if profile is None:
    sys.exit("karabiner.json 에 프로필이 없습니다")

rules = profile.setdefault("complex_modifications", {}).setdefault("rules", [])
rules[:] = [r for r in rules if r.get("description") != crd_rule["description"]]
rules.insert(0, crd_rule)
print(f"프로필 '{profile.get('name')}' 에 규칙 추가: {crd_rule['description']}")

def maps_caps_to_f19(manipulators):
    return any(m.get("from", {}).get("key_code") == "caps_lock"
               and any(t.get("key_code") == "f19" for t in m.get("to", []))
               for m in manipulators)

has_caps_f19 = maps_caps_to_f19(profile.get("simple_modifications", [])) or any(
    maps_caps_to_f19(r.get("manipulators", [])) for r in rules)
if not has_caps_f19:
    rules.insert(1, caps_rule)
    print(f"캡스락 -> F19 매핑이 없어 함께 추가: {caps_rule['description']}")

with open(config_path, "w") as f:
    json.dump(config, f, indent=4, ensure_ascii=False)
    f.write("\n")
EOF

echo "적용 완료. Karabiner-Elements가 karabiner.json 변경을 자동으로 다시 읽습니다."
echo "되돌리려면: cp \"$BACKUP\" \"$CONFIG\""
