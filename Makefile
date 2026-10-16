# Hangar — common tasks. The Xcode project is generated from project.yml; never commit it.

PROJECT = Hangar.xcodeproj
SCHEME = Hangar
BUILD_DIR = build
SWIFTLINT_CONFIG = $(HOME)/.config/swiftlint/.swiftlint.yml

.PHONY: project build test format lint run

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
