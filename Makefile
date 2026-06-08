PROJECT = Minesweeper.xcodeproj
SCHEME = Minesweeper
CONFIG = Debug
DERIVED_DATA = build
APP = $(DERIVED_DATA)/Build/Products/$(CONFIG)/Minesweeper.app

XCODEBUILD = xcodebuild \
	-project $(PROJECT) \
	-scheme $(SCHEME) \
	-configuration $(CONFIG) \
	-derivedDataPath $(DERIVED_DATA) \
	CODE_SIGN_IDENTITY="" \
	CODE_SIGNING_REQUIRED=NO

.PHONY: build run clean

build:
	$(XCODEBUILD) build

run: build
	@if pgrep -xq Minesweeper; then \
		osascript -e 'tell application "Minesweeper" to quit' 2>/dev/null || true; \
		pkill -x Minesweeper 2>/dev/null || true; \
		for i in 1 2 3 4 5 6 7 8 9 10; do \
			pgrep -xq Minesweeper || break; \
			sleep 0.2; \
		done; \
	fi
	open "$(CURDIR)/$(APP)"

clean:
	$(XCODEBUILD) clean
	rm -rf $(DERIVED_DATA)
