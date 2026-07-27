import ServiceManagement
import SwiftUI

@main
struct VinylApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: VinylAppDelegate
    @StateObject private var model = AppModel()

    init() {
#if DEBUG
        WallpaperSnapshot.runIfRequested()
#endif
    }

    var body: some Scene {
        Window("Vinyl", id: "main") {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    model.start()
                }
        }
        .defaultSize(width: 1180, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Refresh Spotify") {
                    model.refresh()
                }
                .keyboardShortcut("r")
                .disabled(!model.isConnected)

                Button(model.isWallpaperEnabled ? "Hide Desktop Artwork" : "Show Desktop Artwork") {
                    model.setWallpaperEnabled(!model.isWallpaperEnabled)
                }
                .keyboardShortcut("d")
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

final class VinylAppDelegate: NSObject, NSApplicationDelegate {
    private var windowCloseObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hasSession = (try? SpotifySessionStore.load()) != nil

        if hasSession {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
                for window in NSApp.windows where window.canBecomeMain {
                    window.close()
                }
            }
            try? SMAppService.mainApp.register()
        }

        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let hasMainWindows = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
                if !hasMainWindows {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        return true
    }
}
