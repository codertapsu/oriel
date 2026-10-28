SCHEME      := Oriel
PROJECT     := Oriel.xcodeproj
CONFIG_DIR  := build
DIST        := dist
VERSION     := $(shell sed -n -E 's/^ +MARKETING_VERSION: *"?([^"]*)"?.*$$/\1/p' project.yml)
PACKAGES    := $(wildcard Packages/*)
TOOL_LIST   := xcodegen swiftlint swiftformat
# UI tests need macOS Automation Mode, which asks for an admin password unless
# `automationmodetool enable-automationmode-without-authentication` has been run. Opt in with ORIEL_UI_TESTS=1.
UI_TESTS    := $(if $(filter 1,$(ORIEL_UI_TESTS)),,-skip-testing:OrielUITests)
# xcodebuild hands only TEST_RUNNER_-prefixed variables to test processes, so `test` forwards ORIEL_TCC_TESTS that way.
# Extra xcodebuild arguments for build, test and universal-check; CI signs ad hoc with them (.github/workflows/ci.yml).
XCODEBUILD_FLAGS ?=

.PHONY: generate build run test lint universal-check install release-dry-run clean tools

tools:
	@for t in $(TOOL_LIST); do command -v $$t >/dev/null || { echo "missing $$t (brew install $$t)"; exit 1; }; done

generate: tools
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' -configuration Debug build $(XCODEBUILD_FLAGS)

run: build
	@pkill -x Oriel 2>/dev/null || true
	@for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x Oriel >/dev/null || break; sleep 0.2; done
	open "$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $$2; exit}')/Oriel.app"

test: generate
	TEST_RUNNER_ORIEL_TCC_TESTS="$(ORIEL_TCC_TESTS)" xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' test $(UI_TESTS) \
	$(XCODEBUILD_FLAGS)
	@for p in $(PACKAGES); do echo "== $$p"; swift test --package-path "$$p" || exit 1; done

lint: tools
	swiftlint --strict
	swiftformat --lint .

universal-check: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=macOS' \
	ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CONFIGURATION_BUILD_DIR=$(CURDIR)/$(CONFIG_DIR)/Release build $(XCODEBUILD_FLAGS)
	lipo -archs $(CONFIG_DIR)/Release/Oriel.app/Contents/MacOS/Oriel | grep -q "x86_64 arm64\|arm64 x86_64"
	lipo -archs $(CONFIG_DIR)/Release/Oriel.app/Contents/Helpers/oriel | grep -q "x86_64 arm64\|arm64 x86_64"
	arch -x86_64 $(CONFIG_DIR)/Release/Oriel.app/Contents/MacOS/Oriel --self-test
	$(CONFIG_DIR)/Release/Oriel.app/Contents/MacOS/Oriel --self-test

install: generate
	bash scripts/install.sh        # archive → export (developer-id) → /Applications → codesign --verify → open

# Needs `source scripts/apple-credentials.env` first. Rehearses a release of the working tree at project.yml's
# version (gate, archive, export, notarize + staple the app and the dmg, verify) and publishes nothing.
release-dry-run: generate
	SKIP_UPLOAD=1 ALLOW_DIRTY=1 RELEASE_TAG=v$(VERSION) bash scripts/release/release-macos.sh

clean:
	rm -rf $(CONFIG_DIR) $(DIST) $(PROJECT)
