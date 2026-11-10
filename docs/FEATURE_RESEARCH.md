# Feature research

Last checked: 2026-11-11

## Inputs reviewed

- Stats issue tracker and README:
  - https://github.com/exelban/stats/issues/1194
  - https://github.com/exelban/stats/issues/3401
  - https://github.com/exelban/stats/issues/3450
  - https://github.com/exelban/stats/issues/2436
  - https://github.com/exelban/stats/issues/1558
  - https://github.com/exelban/stats/issues/3721
- iStat Menus product pages and release history:
  - https://istat-menus.com/
  - https://bjango.com/mac/istatmenus/versionhistory/
  - https://bjango.com/help/istatmenus7/rules/
- MenuMeters:
  - https://www.ragingmenace.com/software/menumeters/
- Sensei:
  - https://cindori.com/sensei
- Notch and Dynamic Island utilities:
  - https://notchy.dev/
  - https://getnotchnook.com/dynamic-island-for-mac
  - https://heycove.app/
- Recent macOS monitor products:
  - https://www.reddit.com/r/MacOS/comments/1wqsqrl/a_9_mb_mac_system_monitor_free_and_open_source/
  - https://github.com/inequitas/performancemonitor
  - https://github.com/macstats/MacStats

## Recurring demand

| Demand | Evidence | Fit for Lumeth |
| --- | --- | --- |
| Long-range history with multiple time windows | Stats users ask for 24-hour, week and month views; iStat and newer monitors ship history graphs | Strong fit. Implemented as a persistent 1m/5m/15m/1h/24h local history |
| Alerts that require a sustained condition | Stats CPU alert issue rejects single-sample spikes; iStat supports rules and persistence | Strong fit. Implemented with thresholds, sustained duration, hysteresis and cooldowns |
| Battery history and discharge trends | Stats asks for battery history; iStat and battery-focused monitors ship it | Strong fit. Battery percentage is part of the shared history store |
| Multiple network interfaces and IP addresses | MenuMeters and Stats requests want interface/IP visibility | Strong fit. Implemented without network access using `getifaddrs` |
| Average and peak temperatures | Users ask for a single thermal summary instead of a long sensor list | Strong fit. Added CPU peak, GPU peak and all-sensor average |
| Fan speed and control | Popular in iStat and Sensei | Speed already reads through SMC when available. Control and fan curves need a privileged helper, which conflicts with Lumeth's App Store sandbox scope |
| Disk SMART, TBW and health | Requested in Stats and provided by some utilities | Deferred. Reliable access needs elevated access or private storage APIs |
| Bluetooth and AirPods battery | Requested by Stats users and included in notch utilities | Deferred. The public, sandbox-safe coverage varies by device and macOS release |
| Process actions and network-per-process | Activity Monitor expectations | Deferred. Process termination is high-risk, and per-process network attribution needs elevated or private instrumentation |
| Music, clipboard, timers and shelf in the notch | Common in NotchNook, Notchy and Cove | Out of scope. These turn Lumeth into a general notch utility rather than a focused system monitor |
| Desktop widgets and iCloud sync | Featured by newer monitors | Deferred. Both add substantial surface area and a second presentation system |

## Implemented in 1.2

- Persistent local history retained for 24 hours.
- History windows: 1 minute, 5 minutes, 15 minutes, 1 hour and 24 hours.
- Downsampled smooth charts with average and peak summaries.
- CPU, memory pressure, temperature and battery alerts.
- Configurable thresholds and sustained duration, with reset hysteresis and a
  five-minute notification cooldown.
- Active network interface list with local IPv4/IPv6 addresses and per-interface
  throughput.
- CPU peak, GPU peak and all-sensor average thermal summary.
- Disk read/write and battery history charts.

All additions use local counters, IOKit, `getifaddrs` and local notifications.
No privileged helper, analytics, remote service or network request is added.
