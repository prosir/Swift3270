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

## Build and install

From the repository root:

```bash
./Scripts/build-app.sh
open Swift3270.app
```

The build script creates a release app bundle and generates the app icon.

If you want to keep Swift3270 permanently on your Mac, move the app bundle to Applications:

```bash
cp -R Swift3270.app /Applications/
open /Applications/Swift3270.app
```

You can also drag `Swift3270.app` to the Applications folder in Finder.

After the app is in `/Applications`, you can delete the source/build folder if you do not want to keep the code locally. The installed app bundle is self-contained, except that it still needs `b3270` from x3270 to be installed on the Mac.

```bash
brew install x3270
```

Because this is currently an unsigned local build, macOS may show a security warning the first time you open it. If that happens, open it with right-click → Open, or allow it in System Settings → Privacy & Security.

## Using it

1. Open `Swift3270.app` from Applications.
2. Create or edit a session.
3. Fill in hostname and port.
4. Enable TLS if your host requires it.
5. Only enable certificate exceptions when you explicitly need them.
6. Connect.

No need to type `L:`, `Y:` or `A:` manually. The wizard builds the x3270 host string for you.

## Version updates

During the compact startup screen Swift3270 checks the latest published GitHub Release. If a newer version exists, the startup screen shows its release notes before opening the terminal.

The update check only requests public release information from GitHub. Swift3270 does not send terminal data, hostnames, session profiles or screen contents.

New releases contain `Swift3270-macOS.zip` and a SHA-256 checksum. After confirmation, Swift3270 downloads both files, validates the checksum and app identity, replaces the current app bundle and relaunches. Releases made before this updater was introduced still fall back to the GitHub release page.

To publish a new visible version:

1. Create a GitHub release with a tag like `v0.1.2`.
2. Put the changelog in the GitHub release notes.
3. Publish the release. GitHub Actions builds the app with the release tag as version and attaches the app archive and checksum automatically.

For a local build with the same version:

```bash
SWIFT3270_VERSION=0.1.2 SWIFT3270_BUILD=3 ./Scripts/build-app.sh
cp -R Swift3270.app /Applications/
```

The app compares its local `CFBundleShortVersionString` with the latest GitHub release tag.

See [`CHANGELOG.md`](CHANGELOG.md) for release notes.

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

## Builds and releases

GitHub Actions checks that the Swift package builds. When a GitHub Release is published, the release job also builds `Swift3270.app`, creates `Swift3270-macOS.zip` plus its SHA-256 checksum, and attaches both to that release.

The updater validates the downloaded checksum, bundle identifier, executable and release version before installation. Code signing and notarization can be added later; the release checksum already prevents corrupted or mismatched archives from being installed.

Local app bundle:

```bash
./Scripts/build-app.sh
cp -R Swift3270.app /Applications/
```

Manual GitHub workflow runs can still upload the raw release binary as a build artifact. Published releases receive the packaged `.app` automatically.

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
