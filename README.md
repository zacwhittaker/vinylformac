# Vinyl for Mac

## Continuing development

Start with [AGENTS.md](AGENTS.md), then read [PROGRESS.md](PROGRESS.md) and [PROJECT_INDEX.md](PROJECT_INDEX.md). These preserve the approved design, current implementation, verification status and next steps across tasks. Update the progress handoff before finishing each substantive task. Historical conversation evidence and the complete baseline file inventory are linked from the index.

Vinyl is a native macOS companion for Spotify that turns each enabled desktop into a calm, animated modern turntable. Album artwork remains the record label, the vinyl follows playback, and the click-through scene stays behind Finder icons and ordinary windows.

This repository is a modernised, independently implemented project. The desktop-window technique was informed by [ibuhs/Luviosa](https://github.com/ibuhs/Luviosa), a GPL-3.0 live-wallpaper project. Vinyl contains no Luviosa source or media and does not represent itself as the upstream project.

## Highlights

- A new Midnight default inspired by modern industrial audio design.
- Fifteen component-aware themes: Midnight, Aurora, Studio, Porcelain, Obsidian, Transparent, Hi-Fi, Tokyo, Technics-inspired, Y2K, Seventies, Braun-inspired, Walnut, Cream, and Gramophone. No trademarked branding is reproduced.
- Independent vinyl, lighting, background, Now Playing, scale, opacity, and layout choices.
- Five included appearance presets, plus create, rename, duplicate, delete, and apply controls.
- One independent Vinyl on/off switch for every connected display.
- Persisted per-display appearance, with an optional shared appearance across all displays.
- Dedicated responsive compositions for standard landscape, ultrawide, super-ultrawide, and portrait displays.
- An Identify Displays overlay and live reaction to connection, disconnection, rotation, and resolution changes.
- Smooth default motion with a coalescing playback animation state machine, progress-aware tonearm, and Reduce Motion support.
- Native sidebar settings with an always-live preview.
- Lightweight menu-bar access to presets and individual displays.
- No analytics or telemetry.

## Playback

Vinyl currently supports the Spotify desktop app. It reads the current track immediately at launch and uses Spotify's local playback notifications to trigger fresh reads. Artwork comes directly from the player, so displaying playback state does not wait for an internet metadata request. Spotify Automation access must be allowed in System Settings. It does not require Spotify developer credentials or account authentication.

The renderer consumes a source-neutral `PlayingItem` model so Apple Music or another source can be added without coupling it to wallpaper views. Apple Music is **not currently implemented**; the previous repository did not contain working Apple Music support to preserve.

## Displays and layout

Vinyl creates one non-interactive AppKit window per enabled `NSScreen`, at one level above the static desktop image and below Finder's desktop icons. Display configuration is keyed by the Core Graphics display identifier rather than array order. Settings are retained when a display disconnects.

Automatic layout keeps the turntable at a natural proportion:

- Standard landscape places the deck and Now Playing side by side.
- 21:9 and 32:9 layouts use extra width for information and atmosphere rather than enlarging the record indefinitely.
- Portrait layouts stack the deck above Now Playing instead of cropping a landscape canvas.

Tested layout logic covers 16:10, 16:9, 21:9, 32:9, 4:3, 3:2, and portrait ratios. Actual multi-monitor QA should still be performed on the target hardware before distribution.

## Performance

- The record timeline pauses when playback pauses.
- Spotify artwork URLs are cached by track.
- Artwork is shared by URL loading caches instead of reprocessed per frame.
- Display windows are removed when disabled or disconnected.
- Playback notifications are debounced and rapid changes cancel obsolete animation convergence work.
- Spotify scripts are compiled once, cached, and executed serially off the UI thread. Overlapping refresh requests are coalesced and obsolete reads are discarded.
- The countdown uses a monotonic playback clock. Position corrections and seeks reach the wallpaper without recreating its windows.
- Playback verification runs every fifteen seconds (briefly sooner near track completion), with no polling while paused/stopped, and backs off after read failures. Playback events and manual refresh bypass that wait.
- Display sleep removes wallpaper windows and suspends verification; wake triggers immediate synchronization.
- Record artwork rotates as a persistent Core Animation bitmap layer at the display's requested refresh rate. Play/pause preserves the layer and decoded artwork. A shared 32 MB image cache coalesces concurrent downloads.
- Countdown text updates on playback-second boundaries; the small progress layer animates continuously without a frame timer. Covered wallpaper windows suspend these updates; Low Power Mode stops decorative rotation.
- Exposure uses a static overlay, and disc shadows are separated from the moving artwork to avoid full-scene effects on every frame.
- Launching another Vinyl build closes older instances to avoid duplicate wallpaper windows and background work.

## Requirements and build

- macOS 14 Sonoma or later
- Xcode 26 or later (the project uses file-system-synchronised groups and Metal shaders)
- Spotify for Mac for live playback

1. Open `Vinyl.xcodeproj` in Xcode.
2. Choose an Apple Developer team in Signing & Capabilities if requested.
3. Build and run the `Vinyl` scheme.
4. Open Spotify and play a track.

For a command-line development build:

```sh
xcodebuild -project Vinyl.xcodeproj -scheme Vinyl -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

GitHub release builds should be signed with a Developer ID certificate and notarised. Before distribution, verify the current Spotify artwork and attribution requirements.

## Screenshots

Screenshots are intentionally left as release assets to capture on representative hardware:

- `docs/screenshots/settings-midnight.png`
- `docs/screenshots/portrait-display.png`
- `docs/screenshots/ultrawide-display.png`
- `docs/screenshots/mixed-displays.png`

## Privacy and assets

The app sandbox, hardened runtime configuration, outbound network entitlement, and privacy manifest are retained. Vinyl performs no tracking and sends no developer analytics.

Bundled material textures are CC0. Their provenance and licences are listed in [ASSET_LICENSES.md](ASSET_LICENSES.md). Do not remove that file when redistributing the project.

## Known limitations

- Spotify must be installed and running; Apple Music support remains future work.
- Custom background image picking and user-defined colour entry are represented in the configuration schema but intentionally not exposed until security-scoped bookmark persistence is implemented.
- Friendly display names and Core Graphics display IDs come from macOS; IDs may change after unusual hardware/adapter changes.
- Global system-wide shortcut capture is not enabled, avoiding conflicts and extra accessibility permissions. The app commands use ⌘D and ⌘R while Vinyl is active.
- Automated tests are currently smoke tests rather than a full XCTest target. Physical display hot-plugging and visual quality require hardware QA.

## Existing smoke tests

- `Tests/SpotifyPlaybackEventMonitorSmoke.swift`
- `Tests/SpotifyArtworkLookupSmoke.swift`
- `Tests/PlaybackClockSmoke.swift` checks elapsed time, pause, seek and duration bounds without Spotify.
- `Tests/SpotifyCurrentPlaybackSmoke.swift` verifies a direct read from a running Spotify instance without changing playback.

The artwork smoke test requires network access. Preserve Spotify's current integration behaviour when extending playback support.
