.DEFAULT_GOAL := help

GODOT_BIN ?= godot
PYTHON ?= python3
ADB ?= adb
NODE ?= node
NPM ?= npm

PROJECT := native
ANDROID_APK := builds/android/doodleshooter-port-debug.apk
ANDROID_RELEASE_APK := builds/android/doodleshooter-port-release.apk
IOS_ZIP := builds/ios/doodleshooter-port.zip
SERVER_PYTHON := .venv/bin/python

.PHONY: help import run touch check build android android-release ios \
	install-android server-deps server test-server capture-menus maps map-previews screenshots \
	assets-reference audio-deps assets-audio clean

help:
	@printf '%s\n' \
	  'make import           Import Godot resources' \
	  'make run              Run the desktop game' \
	  'make touch            Run with touch controls visible' \
	  'make check            Run gameplay and LAN checks' \
	  'make build            Export the Android debug APK' \
	  'make android          Export the Android debug APK' \
	  'make android-release  Export a release APK (requires release signing)' \
	  'make ios              Export the iOS project once signing is configured' \
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

android-release: import
	mkdir -p "$(dir $(ANDROID_RELEASE_APK))"
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --export-release Android "$(CURDIR)/$(ANDROID_RELEASE_APK)"

ios: import
	mkdir -p "$(dir $(IOS_ZIP))"
	"$(GODOT_BIN)" --headless --path "$(PROJECT)" --export-debug iOS "$(CURDIR)/$(IOS_ZIP)"

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
	for map in district mexico castle harbor pyramid station forest school military; do \
	  DOODLE_CAPTURE="$(CURDIR)/$(PROJECT)/assets/previews/$$map.png" "$(GODOT_BIN)" --path "$(PROJECT)" --resolution 720x720 -- --capture --preview --map=$$map; \
	done

screenshots: import
	mkdir -p docs/screenshots
	for map in district mexico castle harbor pyramid station forest school military; do \
	  DOODLE_CAPTURE="$(CURDIR)/docs/screenshots/$$map.png" "$(GODOT_BIN)" --path "$(PROJECT)" --resolution 1280x720 -- --capture --scenic --map=$$map; \
	  sips -s format jpeg -s formatOptions 82 "docs/screenshots/$$map.png" --out "docs/screenshots/$$map.jpg" >/dev/null; \
	  rm -f "docs/screenshots/$$map.png"; \
	done

capture-menus: import
	"$(GODOT_BIN)" --path "$(PROJECT)" --script "$(CURDIR)/tools/capture-menus.gd"

assets-reference:
	"$(NODE)" --experimental-vm-modules tools/extract-reference.mjs

audio-deps:
	"$(NPM)" ci --prefix tools

assets-audio:
	"$(NPM)" run audio --prefix tools

clean:
	rm -rf "$(PROJECT)/.godot"
	rm -f "$(ANDROID_APK)" "$(ANDROID_APK).idsig" \
	  "$(ANDROID_RELEASE_APK)" "$(ANDROID_RELEASE_APK).idsig" "$(IOS_ZIP)"
