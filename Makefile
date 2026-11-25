# The display name: bundle, Info.plist names, UI strings (read from the bundle) and DMG volume. Change it here only.
APP_NAME := Menu Bar Reveal
# The executable and artifact base name: the executable target in Package.swift, which names the built binary.
EXECUTABLE := MenuBarReveal
APP := $(APP_NAME).app
BUNDLE := build/$(APP)
INSTALL_DIR := $(HOME)/Applications
ARCHS := arm64 x86_64
# Package.swift sets the minimum macOS once; the bundle's Info.plist takes it from there.
MIN_MACOS = $(shell swift package dump-package | plutil -extract platforms.0.version raw -o - -)
SDK = $(shell xcrun --sdk macosx --show-sdk-path)
# SwiftPM links through clang with --sysroot, from which clang does not read the SDK version. The app would then
# record its minimum macOS as its SDK, and AppKit would keep that release's behaviour. -isysroot names the SDK.
SWIFT_BUILD = swift build -c release $(addprefix --arch ,$(ARCHS)) \
	-Xswiftc -Xclang-linker -Xswiftc -isysroot -Xswiftc -Xclang-linker -Xswiftc "$(SDK)"
BUILT_EXECUTABLE = $(shell $(SWIFT_BUILD) --show-bin-path)/$(EXECUTABLE)
ICON := build/AppIcon.icns
SWIFT_FILES := Package.swift Sources Tests scripts/render-svg.swift

.PHONY: install build test format lint check release
# Plain make only builds; installing quits and replaces the running app, so it is asked for by name.
.DEFAULT_GOAL := build

install:
	APP_NAME="$(APP_NAME)" EXECUTABLE="$(EXECUTABLE)" INSTALL_DIR="$(INSTALL_DIR)" scripts/install.sh

# make release passes ICON in its staging directory, so the release icon is always rendered fresh.
$(ICON): Icon/AppIcon.svg scripts/render-svg.swift
	mkdir -p "$(dir $(ICON))"
	swift scripts/render-svg.swift Icon/AppIcon.svg "$(ICON)"

build: $(ICON)
	$(SWIFT_BUILD)
	APP_NAME="$(APP_NAME)" EXECUTABLE="$(EXECUTABLE)" BUILT_EXECUTABLE="$(BUILT_EXECUTABLE)" ICON="$(ICON)" \
		MIN_MACOS="$(MIN_MACOS)" BUNDLE="$(BUNDLE)" scripts/bundle.sh

test:
	swift test

format:
	swift format format --in-place --recursive $(SWIFT_FILES)

lint:
	swift format lint --strict --recursive $(SWIFT_FILES)

check: lint test build

release:
	APP_NAME="$(APP_NAME)" EXECUTABLE="$(EXECUTABLE)" scripts/release.sh
