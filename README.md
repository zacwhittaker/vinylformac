# Vinyl

Vinyl is a native macOS companion for the Spotify desktop app. It detects the
item currently playing on your Mac and presents its artwork as a live,
click-through turntable scene behind your desktop icons.

## Run it

1. Open `Vinyl.xcodeproj` in Xcode.
2. Select your Apple Developer team in Signing & Capabilities if Xcode asks.
3. Build and run.
4. Open Spotify for Mac and play a track.

Vinyl does not need Spotify developer credentials or an account connection.

## What is already wired up

- Near-instant local detection from Spotify for Mac's playback-change
  notifications.
- Album artwork lookup through Spotify's public embed metadata.
- An AppKit desktop-level window on every connected display.
- A textured turntable scene with a spinning record, album sleeve, tonearm, and
  live playback progress.
- App Sandbox, hardened runtime, and outgoing-network entitlement.
- A privacy manifest declaring no tracking or developer-side data collection.
- A menu-bar control so the desktop can keep running after the main window is
  closed.

## Distribution reality

GitHub release builds are signed with a Developer ID certificate and notarized
by Apple for a normal, warning-free direct-download experience.

Before wider distribution, confirm that the desktop presentation satisfies
Spotify's current attribution and artwork requirements.

## Original implementation

The desktop-window idea was informed by
[ibuhs/Luviosa](https://github.com/ibuhs/Luviosa), a GPL-3.0 live-wallpaper
project. Vinyl is independently implemented and does not include Luviosa source
or media.
