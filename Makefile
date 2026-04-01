SWIFT_FILES = Slide.swift ContentView.swift WebView.swift PresentationWindow.swift RemoteServer.swift PresentApp.swift
TARGET = Present
APP_BUNDLE = $(TARGET).app
APP_CONTENTS = $(APP_BUNDLE)/Contents
APP_MACOS = $(APP_CONTENTS)/MacOS
APP_RESOURCES = $(APP_CONTENTS)/Resources

VERSION := $(shell cat VERSION)
MAJOR_MINOR := $(word 1,$(subst ., ,$(VERSION))).$(word 2,$(subst ., ,$(VERSION)))
PATCH := $(shell git rev-list --count HEAD)

$(APP_BUNDLE): $(SWIFT_FILES)
	mkdir -p $(APP_MACOS) $(APP_RESOURCES)
	swiftc -parse-as-library -framework SwiftUI -framework AppKit -framework WebKit -framework Network -framework UniformTypeIdentifiers -o $(APP_MACOS)/$(TARGET) $(SWIFT_FILES)
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(TARGET)" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.btbytes.present" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(TARGET)" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(MAJOR_MINOR)" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $(PATCH)" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" $(APP_CONTENTS)/Info.plist
	/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" $(APP_CONTENTS)/Info.plist

.PHONY: run
run: $(APP_BUNDLE)
	open $(APP_BUNDLE)

.PHONY: format
format:
	swift-format -i *.swift

.PHONY: clean
clean:
	rm -rf $(APP_BUNDLE) build
