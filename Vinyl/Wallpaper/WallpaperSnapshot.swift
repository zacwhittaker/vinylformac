#if DEBUG
import AppKit
import SwiftUI

/// Debug-only: `Vinyl --snapshot /path/out.png` renders the wallpaper scene to
/// a PNG and exits, so the composition can be checked without Spotify or
/// screen-recording permission. `VINYL_SNAPSHOT_ART` can point at a local
/// image file to stand in for album artwork.
@MainActor
enum WallpaperSnapshot {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let flagIndex = args.firstIndex(of: "--snapshot"),
              args.count > flagIndex + 1 else {
            return
        }
        let path = args[flagIndex + 1]
        let environment = ProcessInfo.processInfo.environment
        let requestedWidth = environment["VINYL_SNAPSHOT_WIDTH"].flatMap(Double.init)
        let requestedHeight = environment["VINYL_SNAPSHOT_HEIGHT"].flatMap(Double.init)
        let sceneExposure = environment["VINYL_SNAPSHOT_EXPOSURE"].flatMap(Double.init) ?? 0
        let size = if let requestedWidth, let requestedHeight {
            CGSize(width: requestedWidth, height: requestedHeight)
        } else {
            NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)
        }

        let item = environment["VINYL_SNAPSHOT_IDLE"] == "1" ? PlayingItem.idle : PlayingItem(
            id: "snapshot",
            title: environment["VINYL_SNAPSHOT_TITLE"] ?? "Lost in the Fire (feat. The Weeknd)",
            artist: environment["VINYL_SNAPSHOT_ARTIST"] ?? "Gesaffelstein",
            collection: environment["VINYL_SNAPSHOT_COLLECTION"] ?? "Hyperion",
            artworkURL: nil,
            spotifyURL: nil,
            isPlaying: true,
            progressMilliseconds: 74_000,
            durationMilliseconds: 208_000
        )

        let renderer = ImageRenderer(
            content: ModernWallpaperView(
                item: item,
                snapshotDate: Date(),
                appearance: AppearanceConfiguration(theme: .midnight, background: .pureBlack),
                animation: AnimationConfiguration(),
                sceneExposure: sceneExposure
            )
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2

        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            // The sandbox denies arbitrary paths; fall back to the container.
            let requested = URL(fileURLWithPath: path)
            let fallback = URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent(requested.lastPathComponent)
            do {
                try png.write(to: requested)
                print("snapshot written to \(requested.path)")
            } catch {
                do {
                    try png.write(to: fallback)
                    print("snapshot written to \(fallback.path)")
                } catch {
                    print("snapshot write failed: \(error)")
                }
            }
        } else {
            print("snapshot rendering failed")
        }
        exit(0)
    }
}
#endif
