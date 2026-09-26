.PHONY: build test e2e install uninstall karabiner hotkey keylog clean

build:
	swift build -c release

test:
	swift test

# 터미널 앱에 손쉬운 사용 권한 필요
e2e:
	./scripts/e2e-test.sh

# 원격 맥: make install ARGS="--ko com.apple.inputmethod.Korean.3SetKorean"
install:
	./scripts/install.sh $(ARGS)

uninstall:
	./scripts/uninstall.sh

# 로컬 맥: Karabiner 규칙 파일 설치
karabiner:
	./scripts/install-karabiner.sh

# 로컬, 원격 공통 (선택): 다음 입력 소스 단축키를 F19로
hotkey:
	./scripts/set-f19-hotkey.sh

# Phase 0 스파이크: 원격에서 CRD가 넘기는 keycode 확인
keylog:
	swift run keylog

clean:
	rm -rf .build
