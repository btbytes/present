TARGET = Present
APP_BUNDLE = $(TARGET).app
VERSION := $(shell cat VERSION)
MAJOR_MINOR := $(word 1,$(subst ., ,$(VERSION))).$(word 2,$(subst ., ,$(VERSION)))
PATCH := $(shell git rev-list --count HEAD)

.PHONY: all clean run

all: $(APP_BUNDLE)

$(APP_BUNDLE): Present.xcodeproj $(wildcard Present/*.swift)
	xcodebuild clean build \
		-project Present.xcodeproj \
		-scheme Present \
		-configuration Release \
		-derivedDataPath build \
		CURRENT_PROJECT_VERSION=$(PATCH) \
		MARKETING_VERSION=$(MAJOR_MINOR) \
		CONFIGURATION_BUILD_DIR=build/Release
	cp -R build/Release/$(APP_BUNDLE) .

run: $(APP_BUNDLE)
	open $(APP_BUNDLE)

clean:
	rm -rf $(APP_BUNDLE) build
