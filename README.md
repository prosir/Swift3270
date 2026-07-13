# Swift3270

Native macOS 3270 app, powered by x3270/b3270.

We wanted the reliability of x3270, but not the XQuartz feeling around it. Swift3270 keeps the proven `b3270` backend and adds a modern SwiftUI interface on top: readable scaling, multiple sessions, a cleaner connection screen and a Mac app that feels normal to use.

## Why this exists 🙂

x3270 works, but the XQuartz UI can feel rough on modern Macs. Scaling is awkward, sessions are not as smooth as they could be, and the whole thing feels more like a workaround than a daily app.

Swift3270 is basically: keep the good engine, replace the shell.

## What it does

- 🖥️ Native macOS app bundle with icon
- 🌙 Dark SwiftUI interface
- 🧩 Multiple saved sessions
- 🔌 Easy connection wizard: hostname, port, LU, TLS and certificate options
- 🔍 Auto-fit terminal scaling
- 🎨 IBM 3279-style colors
- ⌨️ PF1-PF24, PA1-PA3, Enter, Clear, Reset, Attn, SysReq
- 🧹 End key / keypad End clears to end of field/line
- 🔒 Local-only `b3270` process integration
- 🚫 No terminal screen logging, screen export or telemetry

## Requirements

- macOS 13 or newer
- x3270 with `b3270`
- Swift 5.9 or newer if you build from source

Install x3270:

```bash
brew install x3270
```

Swift3270 looks for `b3270` here:

- `/opt/homebrew/bin/b3270`
- `/usr/local/bin/b3270`
- `/opt/local/bin/b3270`
- any `b3270` in `PATH`

Custom backend path:

```bash
SWIFT3270_B3270_PATH=/custom/path/b3270 open Swift3270.app
```

## Build

From the repository root:

```bash
./Scripts/build-app.sh
open Swift3270.app
```

The build script creates a release app bundle and generates the app icon.

## Using it

1. Open `Swift3270.app`.
2. Create or edit a session.
3. Fill in hostname and port.
4. Enable TLS if your host requires it.
5. Only enable certificate exceptions when you explicitly need them.
6. Connect.

No need to type `L:`, `Y:` or `A:` manually. The wizard builds the x3270 host string for you.

## Keyboard and keypad

Common 3270 actions are available from keyboard, menu and keypad:

- Enter, Clear, Reset
- Tab and BackTab
- Home, cursor movement and Delete
- End / Erase-to-end
- PF1-PF24
- PA1-PA3
- Attn and SysReq
- Dup and Field Mark

## Safety / privacy 🔐

Swift3270 does not put a server in between you and the mainframe.

The app starts `b3270` locally and talks to that local process. `b3270` owns the TN3270 connection, TLS behavior and protocol handling.

The app does not:

- store terminal screen contents
- write session output to disk
- export screen data
- send telemetry
- include a remote backend

Saved profiles contain connection settings only: session name, host, port, LU, TLS options and code page.

Certificate exceptions are explicit checkboxes. Normal certificate validation stays the default unless you turn an exception on.

## Releases

GitHub Actions builds the macOS app on pushes, pull requests and manual workflow runs.

Create a release with a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow creates `Swift3270-macOS.zip` and attaches it to the GitHub release.

## Troubleshooting

### b3270 not found

Install x3270:

```bash
brew install x3270
```

Or set:

```bash
SWIFT3270_B3270_PATH=/custom/path/b3270
```

### Certificate hostname mismatch

Only enable the hostname-mismatch checkbox when that exception is expected in your environment.

### Typing does not go to the terminal

Click inside the terminal once. The terminal takes keyboard focus on click.

## License

Swift3270 is released under the BSD 3-Clause License.

x3270/b3270 is a separate project and is also distributed under a BSD-style license. Swift3270 does not vendor x3270; it uses the locally installed `b3270` executable.
