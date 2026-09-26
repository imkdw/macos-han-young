#!/bin/bash
# macOS 단축키 "입력 메뉴에서 다음 소스 선택"(symbolic hotkey 61)을 F19로 등록한다
# 로컬, 원격 맥 모두 캡스락(F19)으로 한영전환하려면 필요하다. 이미 설정했다면 실행하지 않아도 된다.
set -euo pipefail

# parameters: (ASCII 없음 65535, keycode 80 = F19, 수정키 0x800000 = fn)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
  "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>80</integer><integer>8388608</integer></array><key>type</key><string>standard</string></dict></dict>"

/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
echo "다음 입력 소스 선택 단축키를 F19로 설정했습니다. 바로 적용되지 않으면 로그아웃 후 다시 로그인하세요."
