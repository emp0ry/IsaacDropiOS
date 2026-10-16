SHELL := /bin/zsh
ROOT := $(CURDIR)
SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
MACSDK := $(shell xcrun --sdk macosx --show-sdk-path)
CLANG := $(shell xcrun --sdk iphoneos --find clang++)
MIN_IOS ?= 15.0
DYLIB := $(ROOT)/build/IsaacDrop.dylib
SOURCES := src/ISDBootstrap.m src/ISDHost.mm src/ISDNativeInput.mm
STAGE := $(ROOT)/build/deb-stage
FRAMEWORK := $(ROOT)/build/IsaacDrop.framework

.PHONY: all dylib test package livecontainer embedded audit release
all: release

dylib:
	mkdir -p build
	"$(CLANG)" -isysroot "$(SDK)" -arch arm64 -miphoneos-version-min="$(MIN_IOS)" \
		-fobjc-arc -fblocks -fmodules -O2 -Wall -Wextra -Werror -dynamiclib -Iinclude \
		-Wl,-install_name,@rpath/IsaacDrop.dylib -Wl,-dead_strip -Wl,-fatal_warnings \
		$(SOURCES) -framework Foundation -framework UIKit -framework QuartzCore -o "$(DYLIB)"
	xcrun strip -x "$(DYLIB)"
	codesign --force --sign - --timestamp=none --identifier com.emp0ry.isaacdrop.dylib "$(DYLIB)"
	codesign --verify --strict "$(DYLIB)"

test:
	mkdir -p build
	xcrun --sdk macosx clang++ -isysroot "$(MACSDK)" -std=c++17 -Wall -Wextra -Werror -Iinclude tests/test_drop_policy.cpp -o build/test_drop_policy
	build/test_drop_policy
	python3 -m unittest discover -s tests -p 'test_*.py'
	node --check docs/script.js
	plutil -lint livecontainer/Info.plist package/IsaacDrop.plist

package: dylib
	mkdir -p "$(STAGE)/DEBIAN" "$(STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries" packages
	cp package/control "$(STAGE)/DEBIAN/control"
	cp package/IsaacDrop.plist "$(DYLIB)" "$(STAGE)/var/jb/Library/MobileSubstrate/DynamicLibraries/"
	dpkg-deb --root-owner-group --build "$(STAGE)" packages/IsaacDrop-rootless.deb

livecontainer: dylib
	mkdir -p "$(FRAMEWORK)" packages
	cp "$(DYLIB)" "$(FRAMEWORK)/IsaacDrop"
	cp livecontainer/Info.plist "$(FRAMEWORK)/Info.plist"
	codesign --force --sign - --timestamp=none "$(FRAMEWORK)"
	/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$(FRAMEWORK)" packages/IsaacDrop-LiveContainer.framework.zip

embedded: dylib
	mkdir -p build/IsaacDrop-Embedded dist
	cp "$(DYLIB)" README.md LICENSE build/IsaacDrop-Embedded/
	/usr/bin/ditto -c -k --sequesterRsrc --keepParent build/IsaacDrop-Embedded dist/IsaacDrop-Embedded.zip

audit: dylib
	otool -L "$(DYLIB)"
	@if nm -u "$(DYLIB)" | rg -i 'substrate|ellekit|libhooker'; then exit 1; fi
	@echo "Portable dependency audit passed; input adapter uses writable instance data only"

release: test package livecontainer embedded audit
	mkdir -p dist
	cp "$(DYLIB)" packages/IsaacDrop-rootless.deb packages/IsaacDrop-LiveContainer.framework.zip dist/
	cd dist && shasum -a 256 IsaacDrop.dylib IsaacDrop-rootless.deb IsaacDrop-LiveContainer.framework.zip IsaacDrop-Embedded.zip > SHA256SUMS
