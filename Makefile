.DEFAULT_GOAL := help

GODOT_BIN ?= godot
PYTHON ?= python3
ADB ?= adb
NODE ?= node
NPM ?= npm

PROJECT := native
VERSION := $(shell "$(PYTHON)" tools/bump_version.py --version)
VERSION_CODE := $(shell "$(PYTHON)" tools/bump_version.py --code)
ANDROID_APK := builds/android/doodleshooter-port-v$(VERSION)-$(VERSION_CODE)-debug.apk
ANDROID_RELEASE_APK := builds/android/doodleshooter-port-v$(VERSION)-$(VERSION_CODE)-release.apk
ANDROID_RELEASE_UNSIGNED := $(ANDROID_RELEASE_APK:.apk=-unsigned.apk)
IOS_ZIP := builds/ios/doodleshooter-port-v$(VERSION).zip
WINDOWS_EXE := builds/windows/doodleshooter-port-v$(VERSION).exe
LINUX_BIN := builds/linux/doodleshooter-port-v$(VERSION).x86_64
MACOS_ZIP := builds/macos/doodleshooter-port-v$(VERSION).zip
SERVER_PYTHON := .venv/bin/python

.PHONY: ipa help import run touch check build android android-release ios windows linux macos \
	version bump-patch bump-minor bump-major \
	install-android server-deps server test-server capture-menus maps map-previews screenshots \
	assets-reference audio-deps assets-audio clean

help:
	@printf '%s\n' \
	  'make import           Import Godot resources' \
	  'make run              Run the desktop game' \
	  'make touch            Run with touch controls visible' \
	  'make check            Run gameplay and LAN checks' \
	  'make build            Export the Android debug APK' \
	  'make android          Export the Android debug APK (doodleshooter-port-v<version>-<code>-debug.apk)' \
	  'make android-release  Export the release APK (...-release.apk; signed with keys/release.properties)' \
	  'make ios              Export the iOS project once signing is configured' \
	  'make windows          Export the Windows Desktop executable' \
	  'make linux            Export the Linux x86_64 executable' \
	  'make macos            Export the unsigned macOS universal archive' \
	  'make version          Show the current version and version code' \
	  'make bump-patch       Bump patch version and increment version code' \
	  'make bump-minor       Bump minor version and increment version code' \
	  'make bump-major       Bump major version and increment version code' \
	  'make install-android  Install the existing debug APK via ADB' \
	  'make server-deps      Install the online lobby dependencies' \
	  'make server           Run the online lobby server' \
	  'make test-server      Run the Python lobby tests' \
	  'make capture-menus    Save screenshots of the desktop menus' \
	  'make maps             Regenerate the port maps' \
	  'make map-previews     Render the animated map previews' \
	  'make screenshots      Render the README map screenshots (macOS sips)' \
	  'make assets-reference Regenerate maps and models' \
	  'make audio-deps       Install the audio extraction dependencies' \
	  'make assets-audio     Regenerate the audio assets' \
	  'make clean            Remove Godot import cache and exported packages'

import:
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --editor --import

run: import
	"$(GODOT_BIN)" --path "$(PROJECT)"

touch: import
	"$(GODOT_BIN)" --path "$(PROJECT)" -- --touch

check:
	GODOT_BIN="$(GODOT_BIN)" "$(PYTHON)" tools/check.py

build: android

android: import
	mkdir -p "$(dir $(ANDROID_APK))"
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --export-debug Android "$(CURDIR)/$(ANDROID_APK)"

# Godot cannot sign with passwords that contain shell characters, so it exports the unsigned
# "Android Release (arm64)" preset and tools/sign_apk.py signs it with keys/release.properties.
android-release: import
	mkdir -p "$(dir $(ANDROID_RELEASE_APK))"
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --export-release "Android Release (arm64)" "$(CURDIR)/$(ANDROID_RELEASE_UNSIGNED)"
	"$(PYTHON)" tools/sign_apk.py "$(ANDROID_RELEASE_UNSIGNED)" "$(ANDROID_RELEASE_APK)" keys/release.properties
	rm -f "$(ANDROID_RELEASE_UNSIGNED)"

# Signed IPA from the iOS preset: builds/ios/doodleshooter-port-v<version>-<build>-release.ipa.
# Team from keys/ios.properties; IPA_METHOD=debugging|release-testing|app-store-connect.
ipa: import
	GODOT_BIN="$(GODOT_BIN)" tools/export_ipa.sh "$(PROJECT)" doodleshooter-port

ios: import
	mkdir -p "$(dir $(IOS_ZIP))"
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --export-debug iOS "$(CURDIR)/$(IOS_ZIP)"

windows: import
	mkdir -p "$(dir $(WINDOWS_EXE))"
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --export-release "Windows Desktop" "$(CURDIR)/$(WINDOWS_EXE)"

linux: import
	mkdir -p "$(dir $(LINUX_BIN))"
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --export-release Linux "$(CURDIR)/$(LINUX_BIN)"

macos: import
	mkdir -p "$(dir $(MACOS_ZIP))"
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --export-release macOS "$(CURDIR)/$(MACOS_ZIP)"

version:
	"$(PYTHON)" tools/bump_version.py --show

bump-patch:
	"$(PYTHON)" tools/bump_version.py patch

bump-minor:
	"$(PYTHON)" tools/bump_version.py minor

bump-major:
	"$(PYTHON)" tools/bump_version.py major

install-android:
	@test -f "$(ANDROID_APK)" || { printf '%s\n' 'Debug APK missing. Run make android first.' >&2; exit 1; }
	"$(ADB)" install -r "$(ANDROID_APK)"

server-deps:
	"$(PYTHON)" -m venv .venv
	"$(SERVER_PYTHON)" -m pip install -r server/requirements.txt

server:
	"$(SERVER_PYTHON)" server/lobby.py

test-server:
	"$(SERVER_PYTHON)" -m unittest discover -s tests -v

maps:
	"$(PYTHON)" tools/make-maps.py

map-previews: import
	for map in district jungle mexico castle harbor pyramid station forest school military; do \
	  DOODLE_CAPTURE="$(CURDIR)/$(PROJECT)/assets/previews/$$map.png" "$(GODOT_BIN)" --path "$(PROJECT)" --resolution 720x720 -- --capture --preview --map=$$map; \
	done

screenshots: import
	mkdir -p docs/screenshots
	for map in district jungle mexico castle harbor pyramid station forest school military; do \
	  DOODLE_CAPTURE="$(CURDIR)/docs/screenshots/$$map.png" "$(GODOT_BIN)" --path "$(PROJECT)" --resolution 1280x720 -- --capture --scenic --map=$$map; \
	  sips -s format jpeg -s formatOptions 82 "docs/screenshots/$$map.png" --out "docs/screenshots/$$map.jpg" >/dev/null; \
	  rm -f "docs/screenshots/$$map.png"; \
	done

capture-menus: import
	"$(GODOT_BIN)" --path "$(PROJECT)" --script "$(CURDIR)/tools/capture-menus.gd"

assets-reference:
	"$(NODE)" --experimental-vm-modules tools/extract-reference.mjs
	"$(NODE)" --experimental-vm-modules tools/extract-jungle.mjs

audio-deps:
	"$(NPM)" ci --prefix tools

assets-audio:
	"$(NPM)" run audio --prefix tools

clean:
	rm -rf "$(PROJECT)/.godot"
	rm -f builds/android/*.apk builds/android/*.idsig \
	  builds/ios/*.zip builds/windows/*.exe builds/linux/*.x86_64 builds/macos/*.zip
