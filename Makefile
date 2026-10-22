SHELL := /bin/zsh
ROOT := $(CURDIR)
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
MACSDK := $(shell xcrun --sdk macosx --show-sdk-path)
CLANG := $(shell xcrun --sdk iphoneos --find clang++)
MIN_IOS ?= 15.0
DYLIB := $(ROOT)/build/IsaacFixes.dylib
PLAYCOVER_DYLIB := $(ROOT)/build/IsaacFixes-PlayCover.dylib
SOURCES := src/ISDBootstrap.m src/ISDHost.mm src/ISDNativeInput.mm src/ISDRestartKey.m src/ISDFullscreen.m src/ISDCursorAutoHide.m src/IESKeyboard.m src/IESInputContext.m src/ISDMiniHUD.mm src/ISDPlanetarium.mm
STAGE := $(ROOT)/build/fixes-deb-stage
FRAMEWORK := $(ROOT)/build/IsaacFixes.framework

.PHONY: all dylib test package livecontainer embedded playcover audit release
all: release

dylib:
	mkdir -p build
	"$(CLANG)" -isysroot "$(SDK)" -arch arm64 -miphoneos-version-min="$(MIN_IOS)" \
		-fobjc-arc -fblocks -fmodules -O2 -Wall -Wextra -Werror -dynamiclib -Iinclude \
		-Wl,-install_name,@rpath/IsaacFixes.dylib -Wl,-dead_strip -Wl,-fatal_warnings \
		$(SOURCES) -framework Foundation -framework UIKit -framework QuartzCore -o "$(DYLIB)"
	xcrun strip -x "$(DYLIB)"
	codesign --force --sign - --timestamp=none --identifier com.emp0ry.isaacfixes.dylib "$(DYLIB)"
	codesign --verify --strict "$(DYLIB)"

test:
	mkdir -p build
	xcrun --sdk macosx clang++ -isysroot "$(MACSDK)" -std=c++17 -Wall -Wextra -Werror -Iinclude tools/validation/test_drop_policy.cpp -o build/test_drop_policy
	build/test_drop_policy
	xcrun --sdk macosx clang++ -isysroot "$(MACSDK)" -std=c++17 -Wall -Wextra -Werror -Iinclude tools/check_restart_policy.cpp -o build/test_restart_policy
	build/test_restart_policy
	xcrun --sdk macosx clang++ -isysroot "$(MACSDK)" -std=c++17 -Wall -Wextra -Werror -Iinclude tools/check_mini_hud.cpp -o build/check_mini_hud
	build/check_mini_hud
	xcrun --sdk macosx clang++ -isysroot "$(MACSDK)" -std=c++17 -Wall -Wextra -Werror -Iinclude tools/check_planetarium.cpp -o build/check_planetarium
	build/check_planetarium
	xcrun --sdk macosx clang++ -isysroot "$(MACSDK)" -std=c++17 -Wall -Wextra -Werror -Iinclude tools/check_presentation.cpp -o build/check_presentation
	build/check_presentation
	xcrun --sdk macosx clang -isysroot "$(MACSDK)" -fobjc-arc -fblocks -Wall -Wextra -Werror \
		-Itools/check_support -Iinclude src/ISDRestartKey.m tools/check_restart_key.m \
		-framework Foundation -o build/check_restart_key
	build/check_restart_key
	build/check_restart_key reverse
	python3 -m unittest discover -s tools/validation -p 'test_*.py'
	xcrun --sdk macosx clang -isysroot "$(MACSDK)" -fobjc-arc -fblocks -Wall -Wextra -Werror \
		-DIES_HOST_CHECK=1 -Iinclude src/IESKeyboard.m src/IESInputContext.m tools/check_enter_keyboard.m -framework Foundation -o build/check_enter_keyboard
	build/check_enter_keyboard
	xcrun --sdk macosx clang -isysroot "$(MACSDK)" -fobjc-arc -fblocks -Wall -Wextra -Werror \
		-Iinclude src/ISDFullscreen.m tools/check_fullscreen.m -framework Foundation -o build/check_fullscreen
	build/check_fullscreen
	xcrun --sdk macosx clang -isysroot "$(MACSDK)" -fobjc-arc -fblocks -Wall -Wextra -Werror \
		-Iinclude src/ISDCursorAutoHide.m src/IESInputContext.m tools/check_cursor_autohide.m -framework Foundation -framework CoreGraphics -o build/check_cursor_autohide
	build/check_cursor_autohide
	node --check docs/script.js
	plutil -lint livecontainer/Info.plist package/IsaacFixes.plist

package: dylib
	mkdir -p "$(STAGE)/DEBIAN" "$(STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries" packages
	cp package/control "$(STAGE)/DEBIAN/control"
	cp package/IsaacFixes.plist "$(DYLIB)" "$(STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries/"
	dpkg-deb --root-owner-group --build "$(STAGE)" packages/IsaacFixes-rootless.deb

livecontainer: dylib
	mkdir -p "$(FRAMEWORK)" packages
	cp "$(DYLIB)" "$(FRAMEWORK)/IsaacFixes"
	cp livecontainer/Info.plist "$(FRAMEWORK)/Info.plist"
	codesign --force --sign - --timestamp=none "$(FRAMEWORK)"
	/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$(FRAMEWORK)" packages/IsaacFixes-LiveContainer.framework.zip

embedded: dylib
	mkdir -p build/IsaacFixes-Embedded dist
	cp "$(DYLIB)" README.md LICENSE CHANGELOG.md build/IsaacFixes-Embedded/
	/usr/bin/ditto -c -k --sequesterRsrc --keepParent build/IsaacFixes-Embedded dist/IsaacFixes-Embedded.zip

playcover: dylib
	xcrun vtool -set-build-version maccatalyst 15.0 15.0 -replace -output "$(PLAYCOVER_DYLIB)" "$(DYLIB)"
	codesign --force --sign - --timestamp=none --identifier com.emp0ry.isaacfixes.dylib "$(PLAYCOVER_DYLIB)"
	codesign --verify --strict "$(PLAYCOVER_DYLIB)"

audit: dylib
	otool -L "$(DYLIB)"
	@if nm -u "$(DYLIB)" | rg -i 'substrate|ellekit|libhooker|CGEventPost|CGEventTap|UIKitMacHelper'; then exit 1; fi
	@echo "Portable dependency audit passed; input adapter uses writable instance data only"

release: test package livecontainer embedded playcover audit
	mkdir -p dist
	cp "$(DYLIB)" "$(PLAYCOVER_DYLIB)" packages/IsaacFixes-rootless.deb packages/IsaacFixes-LiveContainer.framework.zip dist/
	cd dist && shasum -a 256 IsaacFixes.dylib IsaacFixes-PlayCover.dylib IsaacFixes-rootless.deb IsaacFixes-LiveContainer.framework.zip IsaacFixes-Embedded.zip > SHA256SUMS
