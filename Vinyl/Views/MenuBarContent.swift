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
            "Vinyl Enabled",
            isOn: Binding(
                get: { model.isWallpaperEnabled },
                set: { model.setWallpaperEnabled($0) }
            )
        )

        Menu("Preset") {
            ForEach(model.configurationStore.presets) { preset in
                Button(preset.name) { model.applyPreset(preset) }
            }
        }

        Menu("Displays") {
            ForEach(model.displayManager.displays) { display in
                Toggle(
                    display.name,
                    isOn: Binding(
                        get: { model.configurationStore.configuration.isEnabled(displayID: display.id) },
                        set: { enabled in
                            model.configurationStore.ensureDisplay(display.id)
                            model.configurationStore.configuration.displayConfigurations[display.id]?.enabled = enabled
                        }
                    )
                )
            }
        }

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
