.PHONY: help build test app run install uninstall clean

APP := USBNotifier

help:
	@echo "make build      - swift build -c release"
	@echo "make test       - swift test"
	@echo "make app        - assemble macos/$(APP).app (ad-hoc signed)"
	@echo "make run        - build the bundle and launch it from macos/"
	@echo "make install    - copy the bundle to /Applications and launch it"
	@echo "make uninstall  - quit and remove /Applications/$(APP).app"
	@echo "make clean      - remove build products"

build:
	cd macos && swift build -c release

test:
	cd macos && swift test

app:
	bash macos/scripts/build.sh

run: app
	# A copy from /Applications would run alongside and double every notification.
	pkill -x $(APP) || true
	open macos/$(APP).app

install: app
	pkill -x $(APP) || true
	rm -rf /Applications/$(APP).app
	# ditto, not cp -R: it preserves the bundle's extended attributes and signature layout.
	ditto macos/$(APP).app /Applications/$(APP).app
	open /Applications/$(APP).app

uninstall:
	pkill -x $(APP) || true
	rm -rf /Applications/$(APP).app

clean:
	cd macos && swift package clean
	rm -rf macos/$(APP).app
