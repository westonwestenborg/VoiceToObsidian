# VoiceToObsidian Build Automation
# Usage: make [target]

SCHEME = VoiceToObsidian
DESTINATION = platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
BUNDLE_ID = com.example.VoiceToObsidian
DERIVED_DATA = build

.PHONY: build test run clean log help

help:
	@echo "Available targets:"
	@echo "  make build  - Build the project"
	@echo "  make test   - Run all tests"
	@echo "  make run    - Build, install, and launch on simulator"
	@echo "  make clean  - Remove build artifacts"
	@echo "  make log    - Stream app logs from simulator"

build:
	xcodebuild -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		build

test:
	xcodebuild -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		test

run: build-for-run
	xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install booted $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/VoiceToObsidian.app
	xcrun simctl launch booted $(BUNDLE_ID)

build-for-run:
	xcodebuild -scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		build

clean:
	rm -rf $(DERIVED_DATA)
	xcodebuild -scheme $(SCHEME) clean 2>/dev/null || true

log:
	xcrun simctl spawn booted log stream \
		--predicate 'subsystem == "com.voicetoobsidian.app"' \
		--level debug
