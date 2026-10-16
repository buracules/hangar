# Hangar — common tasks. The Xcode project is generated from project.yml; never commit it.

PROJECT = Hangar.xcodeproj
SCHEME = Hangar
BUILD_DIR = build
SWIFTLINT_CONFIG = $(HOME)/.config/swiftlint/.swiftlint.yml

.PHONY: project build test format lint run release install

project:
	xcodegen generate -q

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(BUILD_DIR) build

test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(BUILD_DIR) test

format:
	xcrun swift-format format --in-place --recursive Sources Tests

lint:
	xcrun swift-format lint --recursive Sources Tests
	swiftlint lint --quiet --config $(SWIFTLINT_CONFIG) Sources Tests

run: build
	pkill -x Hangar || true
	open $(BUILD_DIR)/Build/Products/Debug/Hangar.app

# Signed and notarized DMG in dist/ (see Scripts/release.sh for the one-time setup)
release:
	./Scripts/release.sh

# Builds the release app and puts it in /Applications, pointing the hangar CLI at it
install:
	SKIP_NOTARIZE=1 SIGN_IDENTITY="Apple Development" ./Scripts/release.sh
	pkill -x Hangar || true
	rm -rf /Applications/Hangar.app
	cp -R build/Build/Products/Release/Hangar.app /Applications/
	ln -sf /Applications/Hangar.app/Contents/MacOS/Hangar $(HOME)/.local/bin/hangar
	open /Applications/Hangar.app
