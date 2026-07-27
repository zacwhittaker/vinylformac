import AppKit
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button("Show Vinyl") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        if let item = model.currentItem {
            Text(item.title)
            Text(item.artist)
                .foregroundStyle(.secondary)
        } else if model.isSpotifyRunning {
            Text("Nothing playing")
                .foregroundStyle(.secondary)
        } else {
            Text("Spotify not running")
                .foregroundStyle(.secondary)
        }

        Toggle(
            "Artwork on Desktop",
            isOn: Binding(
                get: { model.isWallpaperEnabled },
                set: { model.setWallpaperEnabled($0) }
            )
        )

        Button("Refresh Now") {
            model.refresh()
        }
        .disabled(model.isRefreshing)

        Divider()

        Button("Quit Vinyl") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
