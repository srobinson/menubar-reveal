APP := Menubar Reveal.app
BUNDLE := build/$(APP)
INSTALL_DIR := $(HOME)/Applications

.PHONY: install build

install: build
	-pkill -x MenubarReveal
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(APP)"
	cp -R "$(BUNDLE)" "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/$(APP)"

build:
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS"
	swiftc -O -swift-version 6 -target arm64-apple-macos14.0 Sources/*.swift -o "$(BUNDLE)/Contents/MacOS/MenubarReveal"
	cp Info.plist "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign - "$(BUNDLE)"
