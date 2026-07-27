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
        let size = NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)

        let item = PlayingItem(
            id: "snapshot",
            title: "Snapshot",
            artist: "Vinyl",
            collection: nil,
            artworkURL: nil,
            spotifyURL: nil,
            isPlaying: false,
            progressMilliseconds: 74_000,
            durationMilliseconds: 208_000
        )

        let renderer = ImageRenderer(
            content: AlbumCanvasWallpaperView(item: item, snapshotDate: Date())
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
