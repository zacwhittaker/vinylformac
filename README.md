# Vinyl

Vinyl is a native macOS companion for Spotify. It reads the item currently
playing on the connected Spotify account and presents its artwork in a
click-through desktop window behind desktop icons.

This first scaffold deliberately stops at the artwork background. A vinyl
record treatment, animation, playback controls, launch-at-login, and richer
display controls can be layered on later without replacing the Spotify or
wallpaper foundations.

## Run it

1. Open `Vinyl.xcodeproj` in Xcode.
2. In Signing & Capabilities, select your Apple Developer team and replace the
   placeholder bundle identifier (`com.example.Vinyl`).
3. Create an app in the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
4. Add this redirect URI exactly:

   `http://127.0.0.1:8888/callback`

   The explicit port is important. Spotify documents dynamic loopback ports,
   but its current dashboard rejects the equivalent portless URI as insecure.
5. Build and run, then choose **Connect Spotify**. The current developer Client
   ID is already configured; it remains editable in the app for development.

The client ID is public app configuration, not a secret. Vinyl never asks for
or embeds a Spotify client secret. OAuth refresh tokens are stored in the
user's macOS Keychain.

## What is already wired up

- Spotify Authorization Code with PKCE.
- The minimal `user-read-currently-playing` scope.
- Refresh-token handling and disconnect/data deletion.
- Near-instant local refreshes from Spotify for Mac's playback-change
  notification, plus a 30-second Web API fallback with cache bypass and 401/429
  handling.
- Track and podcast episode artwork parsing.
- An AppKit desktop-level window on every connected display.
- App Sandbox, hardened runtime, outgoing networking, and local callback server
  entitlements.
- A privacy manifest declaring no tracking or developer-side data collection.
- A menu-bar control so the desktop can keep running after the main window is
  closed.

## Distribution reality

The Xcode target is shaped for Mac App Store signing, but two external reviews
still stand between a prototype and a public release:

1. New Spotify apps start in Development Mode. They work for the owner and a
   small allowlist; broad public access requires Spotify Extended Quota Mode.
2. Spotify's current policy requires attribution and a link back whenever
   Spotify cover art or metadata is displayed. The in-app experience includes
   both. Before shipping, confirm with Spotify that the desktop presentation is
   acceptable for your exact product.

You will also need the usual release assets and paperwork: a final name and
bundle ID, privacy policy/support URLs, screenshots, App Store description,
Apple distribution signing, and App Review notes explaining the desktop window
and local OAuth callback.

## Original implementation

The desktop-window idea was informed by
[ibuhs/Luviosa](https://github.com/ibuhs/Luviosa), a GPL-3.0 live-wallpaper
project. Vinyl is independently implemented and does not include Luviosa source
or media.
