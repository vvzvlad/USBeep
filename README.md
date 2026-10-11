# USB Notifier

A small macOS menu-bar app that tells you when a USB device is plugged in or unplugged —
with a notification and a sound — and shows the list of connected devices with their link
speed and allocated power.

Based on [ohaiibuzzle/USBNotifier](https://github.com/ohaiibuzzle/USBNotifier).

## Features

- Notification on connect / disconnect; several devices plugged in at once are grouped
  into one notification.
- Separate connect and disconnect sounds, picked from the macOS system sounds.
- Live device list: name, VID:PID, link speed (e.g. `480 Mb/s`), allocated power
  (e.g. `500 mA · 2.5 W`).
- Optional "replace previous notification" mode and launch at login.

Power is the current the host allocated to the device on the 5 V bus, not a measurement
of what it actually draws.

## Requirements

- macOS 14 or later
- Xcode command line tools (Swift 5.9+)

## Build and run

```bash
make test       # unit tests
make run        # build macos/USBNotifier.app and launch it
make install    # install to /Applications and launch
make uninstall
```

The app must run from its bundle: notifications and launch at login do not work for the
bare `swift build` binary.

## License

GPL-3.0, inherited from the upstream project. See [LICENSE](LICENSE).
