# Security Policy

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub:
open the repository's **Security** tab and click **Report a vulnerability**.
Do not open a public issue for security problems.

You can expect a first reply within a week.

## What the app does and does not do

- It reads USB device metadata from IOKit (names, VID:PID, serial number, speed,
  allocated power, serial-port paths). It does not open devices or read their data.
- It makes no network connections and collects nothing.
- It stores only its own settings in the user defaults of its bundle.
