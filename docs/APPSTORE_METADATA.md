# App Store Connect metadata draft

## App information

- Name: `Lumeth`
- Subtitle: `System monitor in your notch`
- Bundle ID: `com.sansi.lumeth`
- SKU: `lumeth-macos`
- Primary category: Utilities
- Price: Free
- Minimum macOS: 14.0
- Copyright: `Lumeth`

## Promotional text

See CPU, memory, network and temperature around the notch. Click the island for
a calm, native dashboard with processors, memory, network, sensors, disks, GPU,
battery and processes.

## Description

Lumeth turns the MacBook notch into a quiet system monitor.

The compact island stays at menu-bar height and shows CPU, memory, network and
temperature without taking over the screen. Click it to open a native dashboard
with:

- Per-core CPU usage, load averages and top processes
- Memory composition, pressure and swap
- Live network throughput and totals
- GPU utilization and memory
- Temperature sensors
- Disk activity and capacity
- Battery level, cycles and health

All readings stay on your Mac. Lumeth has no analytics, advertising, network
requests, background daemon, or privileged helper.

## Keywords

`system monitor,cpu,memory,network,temperature,notch,menu bar,macos`

## URLs

- Support: https://sansi-lcj.github.io/lumeth/support.html
- Privacy: https://sansi-lcj.github.io/lumeth/privacy.html
- Marketing: https://sansi-lcj.github.io/lumeth/

## Screenshots

- `docs/screenshot-overview-2560x1600.png`
- `docs/screenshot-cpu-2560x1600.png`

Both are 2560×1600 and have no alpha channel.

## App Review notes

Lumeth is an accessory app (`LSUIElement`) with no Dock icon. It draws a
compact panel around the MacBook notch and expands into a dashboard when
clicked. It reads public, read-only system counters and IOHID temperature
events; it does not request Accessibility, Input Monitoring, Full Disk Access,
root, or network access. Fan control is intentionally not implemented.

## Current account state

The App Store Connect record exists and version 1.1 build 8 has been submitted.
The current review state is `WAITING_FOR_REVIEW`. Distribution certificates,
the Mac App Store provisioning profile, pricing, availability, age rating,
privacy declaration and screenshots are all configured; see `docs/APPSTORE.md`.
