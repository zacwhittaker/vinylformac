import SwiftUI

@main
struct VinylApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Vinyl", id: "main") {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    model.start()
                }
        }
        .defaultSize(width: 940, height: 690)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Refresh Spotify") {
                    model.refresh()
                }
                .keyboardShortcut("r")
                .disabled(!model.isConnected)
            }
        }

        MenuBarExtra("Vinyl", systemImage: "record.circle") {
            MenuBarContent()
                .environmentObject(model)
                .onAppear {
                    model.start()
                }
        }
        .menuBarExtraStyle(.menu)
    }
}
