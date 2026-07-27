import ServiceManagement
import SwiftUI

@main
struct VinylApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: VinylAppDelegate
    @StateObject private var model = AppModel(startAutomatically: false)

    init() {
        OnboardingProgress.prepare()
#if DEBUG
        WallpaperSnapshot.runIfRequested()
#endif
    }

    var body: some Scene {
        Window("Vinyl", id: "main") {
            VinylRootView()
                .environmentObject(model)
        }
        .defaultSize(width: 980, height: 740)
        .commands {
            CommandGroup(replacing: .appSettings) {
                OpenVinylSettingsButton()
            }
            CommandGroup(replacing: .newItem) {
                Button(model.isWallpaperEnabled ? "Hide Desktop Artwork" : "Show Desktop Artwork") {
                    model.setWallpaperEnabled(!model.isWallpaperEnabled)
                }
                .keyboardShortcut("d")
            }
        }

        MenuBarExtra("Vinyl", image: "VinylMenuBarIcon") {
            MenuBarContent()
                .environmentObject(model)
                .onAppear {
                    if OnboardingProgress.isComplete() {
                        model.start()
                    }
                }
        }
        .menuBarExtraStyle(.menu)
    }
}

final class VinylAppDelegate: NSObject, NSApplicationDelegate {
    private var windowCloseObserver: NSObjectProtocol?
    private var instanceObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Xcode and Finder can launch different builds of the same app. Keep
        // only the newest instance so desktop windows and playback work don't
        // accumulate behind one another.
        let current = NSRunningApplication.current
        let instanceName = Notification.Name("me.shivs.vinyl.instanceStarted")
        let instanceID = String(current.processIdentifier)
        // Sandboxed instances cannot always terminate one another through
        // NSRunningApplication. Each cooperating instance closes itself instead.
        DistributedNotificationCenter.default().postNotificationName(instanceName, object: instanceID,
                                                      userInfo: nil, deliverImmediately: true)
        instanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: instanceName, object: nil, queue: .main
        ) { notification in
            guard let sender = notification.object as? String, sender != instanceID else { return }
            NSApplication.shared.terminate(nil)
        }
        if let bundleID = current.bundleIdentifier {
            for other in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                where other.processIdentifier != current.processIdentifier {
                other.terminate()
            }
        }
        OnboardingProgress.prepare()
        let hasCompletedOnboarding = OnboardingProgress.isComplete()

        if hasCompletedOnboarding {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
                for window in NSApp.windows where window.canBecomeMain {
                    window.close()
                }
            }
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

private struct VinylRootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage(OnboardingProgress.completedVersionKey) private var completedVersion = 0

    var body: some View {
        Group {
            if completedVersion >= OnboardingProgress.currentVersion && !OnboardingProgress.isPreviewMode {
                SettingsRootView()
                    .onAppear { model.start() }
            } else {
                OnboardingView(model: model) {
                    OnboardingProgress.complete()
                    completedVersion = OnboardingProgress.currentVersion
                    model.start()
                    DispatchQueue.main.async {
                        dismissWindow(id: "main")
                    }
                }
            }
        }
    }
}

private struct OpenVinylSettingsButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Settings…") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }.keyboardShortcut(",")
    }
}
