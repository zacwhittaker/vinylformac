import AppKit
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let item = model.currentItem {
            Text(item.title)
            Text(item.artist)
                .foregroundStyle(.secondary)
        } else if model.isPlayerRunning {
            Text("Nothing playing")
                .foregroundStyle(.secondary)
        } else {
            Text("\(model.selectedPlayer.name) not running")
                .foregroundStyle(.secondary)
        }

        Toggle(
            "Show Vinyl on Desktop",
            isOn: Binding(
                get: { model.isWallpaperEnabled },
                set: { model.setWallpaperEnabled($0) }
            )
        )

        Divider()

        Button {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        .keyboardShortcut(",")

<<<<<<< HEAD
        Picker("Music Player", selection: Binding(get: { model.selectedPlayer }, set: { model.selectPlayer($0) })) {
            ForEach(MusicPlayer.allCases) { Text($0.name).tag($0) }
=======
        Button("Refresh Now") {
            model.refresh()
>>>>>>> 10bb768fe8843589f7fb9f1375d2e6e8eaec9fb6
        }

        Divider()

        Button("Quit Vinyl") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
