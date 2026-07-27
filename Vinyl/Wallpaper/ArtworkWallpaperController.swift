import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class ArtworkWallpaperController {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    private var presentations: [CGDirectDisplayID: WallpaperPlaybackPresentation] = [:]
    private var visibilityObservers: [CGDirectDisplayID: NSObjectProtocol] = [:]
    private var currentItem: PlayingItem?
    private var snapshotDate = Date()
    private var screenObserver: NSObjectProtocol?
    private var configuration = AppConfiguration()
    private var identificationVisible = false
    private var playbackActions = PlaybackActions()

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reconcileWindows()
            }
        }
    }

    func setPlaybackActions(_ actions: PlaybackActions) {
        playbackActions = actions
        rebuildWindows(restoringPlaybackState: true)
    }

    func show(_ item: PlayingItem, configuration: AppConfiguration) {
        let contentChanged = currentItem.map { previous in
            previous.progressMilliseconds != item.progressMilliseconds ||
            previous.sampledAt != item.sampledAt ||
            previous.id != item.id ||
            previous.title != item.title ||
            previous.artist != item.artist ||
            previous.collection != item.collection ||
            previous.artworkURL != item.artworkURL ||
            previous.isPlaying != item.isPlaying ||
            previous.durationMilliseconds != item.durationMilliseconds
        } ?? true
        if contentChanged {
            snapshotDate = Date()
        }
        currentItem = item
        let configurationChanged = self.configuration != configuration
        let updatedAppearance = updateAppearanceInPlace(configuration)
        self.configuration = configuration

        // Artwork is view content. Recreating its window destroys the arm's
        // presentation state before SwiftUI can animate to the next song.
        let enabledIDs = Set(enabledScreens.compactMap(\.displayID))
        if (configurationChanged && !updatedAppearance) || Set(windows.keys) != enabledIDs {
            rebuildWindows(restoringPlaybackState: true)
        } else if contentChanged {
            updateWindowContent(with: item)
        }
    }

    /// Sleep removes the windows to stop rendering. Recreate them at the
    /// authoritative transport pose after the first post-wake Spotify read.
    func restore(_ item: PlayingItem, configuration: AppConfiguration) {
        currentItem = item
        self.configuration = configuration
        rebuildWindows(restoringPlaybackState: true)
    }

    func update(configuration: AppConfiguration) {
        let updatedAppearance = updateAppearanceInPlace(configuration)
        self.configuration = configuration
        if !updatedAppearance { rebuildWindows(restoringPlaybackState: true) }
    }

    /// Material/appearance edits update the existing root so the physical arm,
    /// native artwork and progress layers keep their current animation state.
    /// Window policy, enabled displays and animation configuration retain the
    /// established rebuild path.
    private func updateAppearanceInPlace(_ next: AppConfiguration) -> Bool {
        guard configuration.differsOnlyInAppearance(from: next) else { return false }
        for (displayID, presentation) in presentations {
            let appearance = next.appearance(for: String(displayID))
            if presentation.appearance != appearance { presentation.appearance = appearance }
        }
        return true
    }

    func setIdentificationVisible(_ visible: Bool) {
        identificationVisible = visible
        rebuildWindows(restoringPlaybackState: true)
    }

    func hide() {
        currentItem = nil
        closeWindows()
    }

    private func rebuildWindows(restoringPlaybackState: Bool) {
        closeWindows()
        guard let currentItem else { return }

        for (index, screen) in enabledScreens.enumerated() {
            createWindow(on: screen, index: index, item: currentItem,
                         restoringPlaybackState: restoringPlaybackState)
        }
    }

    /// Display notifications describe the whole topology. Preserve windows
    /// whose display IDs still exist, remove only detached displays and add
    /// only new ones, so an ordinary reconfiguration cannot restart motion.
    private func reconcileWindows() {
        guard let currentItem else { return }
        let screens = enabledScreens
        let desiredIDs = Set(screens.compactMap(\.displayID))
        for displayID in windows.keys.filter({ !desiredIDs.contains($0) }) {
            removeWindow(for: displayID)
        }
        if identificationVisible {
            rebuildWindows(restoringPlaybackState: true)
            return
        }
        for (index, screen) in screens.enumerated() {
            guard let displayID = screen.displayID else { continue }
            if let window = windows[displayID] {
                window.setFrame(screen.frame, display: true)
                window.contentView?.frame = window.contentLayoutRect
            } else {
                createWindow(on: screen, index: index, item: currentItem,
                             restoringPlaybackState: true)
            }
        }
    }

    private func createWindow(on screen: NSScreen, index: Int, item: PlayingItem,
                              restoringPlaybackState: Bool) {
        guard let displayID = screen.displayID else { return }
        let window = DesktopArtworkWindow(screen: screen, gameModeEnabled: configuration.gameModeEnabled ?? false)
        let presentation = WallpaperPlaybackPresentation(
            item: item,
            appearance: configuration.appearance(for: String(displayID)),
            restoresPlaybackState: restoringPlaybackState
        )
        presentations[displayID] = presentation
        visibilityObservers[displayID] = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak presentation, weak window] _ in
            Task { @MainActor in
                presentation?.isVisible = window?.occlusionState.contains(.visible) ?? false
            }
        }
        let hostingView = NSHostingView(
            rootView: WallpaperPlaybackRoot(
                presentation: presentation,
                animation: configuration.animations,
                playbackActions: playbackActions,
                sceneExposure: configuration.sceneExposure(for: String(displayID)),
                displayName: screen.localizedName,
                identificationNumber: identificationVisible ? index + 1 : nil
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        window.contentView = hostingView
        window.setFrame(screen.frame, display: true)
        window.contentView?.frame = window.contentLayoutRect
        window.orderFrontRegardless()
        windows[displayID] = window
    }

    private func removeWindow(for displayID: CGDirectDisplayID) {
        if let observer = visibilityObservers.removeValue(forKey: displayID) {
            NotificationCenter.default.removeObserver(observer)
        }
        presentations.removeValue(forKey: displayID)
        guard let window = windows.removeValue(forKey: displayID) else { return }
        window.orderOut(nil)
        window.close()
    }

    private func closeWindows() {
        for observer in visibilityObservers.values { NotificationCenter.default.removeObserver(observer) }
        visibilityObservers.removeAll()
        for window in windows.values {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        presentations.removeAll()
    }

    private func updateWindowContent(with item: PlayingItem) {
        for presentation in presentations.values { presentation.item = item }
    }


    private var enabledScreens: [NSScreen] {
        NSScreen.screens.filter { screen in
            guard let displayID = screen.displayID else { return false }
            return configuration.isEnabled(displayID: String(displayID))
        }
    }
}

@MainActor
private final class WallpaperPlaybackPresentation: ObservableObject {
    @Published var item: PlayingItem
    @Published var appearance: AppearanceConfiguration
    let restoresPlaybackState: Bool
    @Published var isVisible = true
    init(item: PlayingItem, appearance: AppearanceConfiguration, restoresPlaybackState: Bool) {
        self.item = item
        self.appearance = appearance
        self.restoresPlaybackState = restoresPlaybackState
    }
}

private struct WallpaperPlaybackRoot: View {
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @ObservedObject var presentation: WallpaperPlaybackPresentation
    let animation: AnimationConfiguration
    let playbackActions: PlaybackActions
    let sceneExposure: Double
    let displayName: String?
    let identificationNumber: Int?

    var body: some View {
        ModernWallpaperView(item: presentation.item, snapshotDate: Date(),
                            appearance: presentation.appearance, animation: animation,
                            playbackActions: playbackActions, sceneExposure: sceneExposure,
                            displayName: displayName, identificationNumber: identificationNumber,
                            restoresPlaybackState:presentation.restoresPlaybackState)
            .environment(\.playbackRenderingSuspended, !presentation.isVisible)
            .environment(\.playbackMotionReduced, lowPower)
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
    }
}

private final class DesktopArtworkWindow: NSWindow {
    init(screen: NSScreen, gameModeEnabled: Bool) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // One step above the static desktop image and below Finder's icon level.
        level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        var behavior: NSWindow.CollectionBehavior = [.stationary, .ignoresCycle]
        if !gameModeEnabled {
            // Desktop-level windows otherwise disappear while the user is in
            // a full-screen Space even though they are visible on desktops.
            behavior.insert(.canJoinAllSpaces)
            behavior.insert(.fullScreenAuxiliary)
        }
        collectionBehavior = behavior
        isOpaque = true
        backgroundColor = .black
        colorSpace = .sRGB
        hasShadow = false
        // SwiftUI's own hit-testing keeps the visual surface passive while
        // allowing the now-playing transport buttons to receive clicks.
        ignoresMouseEvents = false
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
    }
}
