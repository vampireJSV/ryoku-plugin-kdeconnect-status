# KDE Connect

A Ryoku shell plugin (`kdeconnect-status`) that shows the live status of the
first reachable/paired KDE Connect device on the bar: a connection glyph, the
device's battery percent, and its unread notification count. The panel also
has quick-action buttons. Status polling is read-only; anything sent to the
device happens only on an explicit button click.

## What it does

- **Service** (`service/Main.qml`): polls `bin/poll.sh` on a timer (default
  every 10s, configurable) and holds the parsed result: `found`, `deviceName`,
  `reachable`, `charge`, `charging`, `notifCount`, `lastPollFailed`.
- **Widget** (`content/Widget.qml`): a diamond glyph (filled when reachable,
  hollow otherwise), the battery percent (with a bolt while charging), and a
  `(N)` unread-notification badge when N > 0. A left click only opens the
  panel.
- **Panel** (`content/Panel.qml`): the device name, connection state, battery,
  and notification count, plus buttons (shown when the device is reachable):

  | button     | runs                                              |
  | ---------- | ------------------------------------------------- |
  | Messages   | `kdeconnect-sms --device <id>`                    |
  | Send file  | `zenity --file-selection`, then `kdeconnect-cli --device <id> --share <file>` |
  | Clipboard  | `kdeconnect-cli --device <id> --send-clipboard`   |
  | Ping       | `kdeconnect-cli --device <id> --ping`             |
  | Find phone | `kdeconnect-cli --device <id> --ring`             |
  | Open app   | `kdeconnect-app`                                  |

  All are fixed argv arrays, never a shell string. No network, no privileged
  commands.

## What it reads and writes

Reads only, over the user session D-Bus, via `bin/poll.sh`:

- `org.kde.kdeconnect` service, `/modules/kdeconnect` `daemon.devices(bb)` to
  find the first paired+reachable device id.
- That device's `org.kde.kdeconnect.device` `name` / `isReachable` properties.
- Its `.battery` interface's `charge` / `isCharging` properties.
- Its `.notifications` interface's `activeNotifications()` method, to count
  unread notifications.

`bin/poll.sh` never calls a KDE Connect method that sends anything. The
actions above run only from the panel buttons, in `service/Main.qml`. The
plugin never writes any file itself;
all output is a single JSON line to stdout that `service/Main.qml` parses.
Settings are read through `pluginApi.pluginSettings` behind a default and
written only through `pluginApi.saveSetting` (the settings panel the bar
renders); the plugin itself never edits `shell.json` or `plugins.json`.

## Requirements

- `kdeconnect` installed and `kdeconnectd` running (autostarted by its own
  package via `/etc/xdg/autostart`).
- At least one device paired via `kdeconnect-cli --pair` or the KDE Connect
  app; otherwise the panel just says "No paired device found."
- `busctl`, `jq`, `kdeconnect-cli`, `kdeconnect-sms`, `kdeconnect-app` and
  `zenity` on PATH (all listed in `dependencies.commands`).

## Settings

| key         | type | default | description            |
| ----------- | ---- | ------- | ----------------------- |
| pollSeconds | int  | 10      | Refresh interval, seconds |

## Preview

Capture a real screenshot of the widget and save it as
`assets/preview-widget.png`, then list it under `files` in `manifest.json`.

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

It lists under **Community** in QS Bar Settings. Publish it only when asked:
`ryoku plugin share kdeconnect-status`.

## Author

vampirejsv <vampirejsv@local>: this plugin is community-made (`official` is false).
