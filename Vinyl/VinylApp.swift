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
            SettingsRootView()
                .environmentObject(model)
                .onAppear {
                    model.start()
                }
        }
        .defaultSize(width: 1120, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Refresh Spotify") {
                    model.refresh()
                }
                .keyboardShortcut("r")

                Button(model.isWallpaperEnabled ? "Hide Desktop Artwork" : "Show Desktop Artwork") {
                    model.setWallpaperEnabled(!model.isWallpaperEnabled)
                }
                .keyboardShortcut("d")
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
    private static let hasLaunchedKey = "Vinyl.hasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hasLaunched = UserDefaults.standard.bool(forKey: Self.hasLaunchedKey)

        if hasLaunched {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
                for window in NSApp.windows where window.canBecomeMain {
                    window.close()
                }
            }
        } else {
            UserDefaults.standard.set(true, forKey: Self.hasLaunchedKey)
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
