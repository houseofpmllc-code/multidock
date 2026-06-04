# MultiDock

Shows your macOS Dock on all secondary monitors, matching your Dock's position (bottom/left/right). Includes hover animations, running-app indicators, and auto-refresh when you add/remove apps from your Dock.

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Install

Open Terminal, `cd` into this folder, then run:

```bash
chmod +x build-app.sh
./build-app.sh
```

This builds the app and produces `MultiDock.app` in the current folder.

**To install:**
```bash
cp -R MultiDock.app /Applications/
open /Applications/MultiDock.app
```

## Usage

- After launching, MultiDock runs silently in the background (no Dock icon).
- A **menu bar icon** (⊟) appears — click it to refresh or quit.
- The Dock mirror appears on every secondary monitor automatically.
- Clicking an app icon **launches** it (or **activates** it if already running).
- A small white dot under the icon indicates the app is currently running.
- MultiDock auto-refreshes every 3 seconds to pick up changes to your Dock.

## Auto-start on login

To have MultiDock start automatically:
1. Open **System Settings → General → Login Items**
2. Click **+** and add `/Applications/MultiDock.app`

## Notes

- MultiDock reads your Dock layout from `~/Library/Preferences/com.apple.dock.plist`.
- It does not require any special permissions.
- To stop it, click the menu bar icon → **Quit MultiDock**.
