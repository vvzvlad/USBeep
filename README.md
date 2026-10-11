# USB Notifier

A small macOS menu-bar app that tells you when a USB device is plugged in or unplugged —
with a notification and a sound — and shows the list of connected devices with their link
speed and allocated power.

Based on [ohaiibuzzle/USBNotifier](https://github.com/ohaiibuzzle/USBNotifier).

## Features

- Notification on connect / disconnect; several devices plugged in at once are grouped
  into one notification.
- Separate connect and disconnect sounds, picked from the macOS system sounds.
- Live device list: category icon, name, vendor, link speed (e.g. `USB 2.0 · 480 Mb/s`)
  and allocated power (e.g. `2.5 W`), with the total in the header.
- VID:PID and serial number of every device; serial-port devices show their
  `/dev/cu.*` path, which is copied to the clipboard on click.
- Optional "replace previous notification" mode and launch at login.

Power is the current the host allocated to the device on the 5 V bus, not a measurement
of what it actually draws.

## Install

Download `USBNotifier.zip` from
[Releases](https://github.com/vvzvlad/USBNotifier/releases), unzip it and move
`USBNotifier.app` to `/Applications`. The build is for Apple Silicon and macOS 14 or later.

The app is ad-hoc signed, not notarized. On the first launch macOS refuses to open it:
open System Settings → Privacy & Security and click "Open Anyway". Alternatively:

```bash
xattr -dr com.apple.quarantine /Applications/USBNotifier.app
```

## Build from source

Requires macOS 14 or later and the Xcode command line tools (Swift 5.9+).

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
