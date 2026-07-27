import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class ArtworkWallpaperController {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]
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
                self?.rebuildWindows()
            }
        }
    }

    func setPlaybackActions(_ actions: PlaybackActions) {
        playbackActions = actions
        rebuildWindows()
    }

    func show(_ item: PlayingItem, configuration: AppConfiguration) {
        let artworkChanged = currentItem?.artworkURL != item.artworkURL
        let contentChanged = currentItem != item
        if contentChanged {
            snapshotDate = Date()
        }
        currentItem = item
        let configurationChanged = self.configuration != configuration
        self.configuration = configuration

        if artworkChanged || configurationChanged || windows.count != enabledScreens.count {
            rebuildWindows()
        } else if contentChanged {
            updateWindowContent(with: item)
        }
    }

    func update(configuration: AppConfiguration) {
        self.configuration = configuration
        rebuildWindows()
    }

    func setIdentificationVisible(_ visible: Bool) {
        identificationVisible = visible
        rebuildWindows()
    }

    func hide() {
        currentItem = nil
        closeWindows()
    }

    private func rebuildWindows() {
        closeWindows()
        guard let currentItem else { return }

        for (index, screen) in enabledScreens.enumerated() {
            guard let displayID = screen.displayID else { continue }
            let window = DesktopArtworkWindow(screen: screen)
            let hostingView = NSHostingView(
                rootView: AnyView(ModernWallpaperView(
                    item: currentItem,
                    snapshotDate: snapshotDate,
                    appearance: configuration.appearance(for: String(displayID)),
                    animation: configuration.animations,
                    playbackActions: playbackActions,
                    sceneExposure: configuration.sceneExposure(for: String(displayID)),
                    displayName: screen.localizedName,
                    identificationNumber: identificationVisible ? index + 1 : nil
                ).environment(\.displayRefreshRate, Double(screen.maximumFramesPerSecond)))
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
    }

    private func closeWindows() {
        for window in windows.values {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    private func updateWindowContent(with item: PlayingItem) {
        for (displayID, window) in windows {
            guard let hostingView = window.contentView as? NSHostingView<AnyView> else {
                continue
            }
            let refreshRate = window.screen.map { Double($0.maximumFramesPerSecond) } ?? 60
            hostingView.rootView = AnyView(ModernWallpaperView(
                item: item,
                snapshotDate: snapshotDate,
                appearance: configuration.appearance(for: String(displayID)),
                animation: configuration.animations,
                playbackActions: playbackActions,
                sceneExposure: configuration.sceneExposure(for: String(displayID))
            ).environment(\.displayRefreshRate, refreshRate))
        }
    }


    private var enabledScreens: [NSScreen] {
        NSScreen.screens.filter { screen in
            guard let displayID = screen.displayID else { return false }
            return configuration.isEnabled(displayID: String(displayID))
        }
    }
}

private final class DesktopArtworkWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // One step above the static desktop image and below Finder's icon level.
        level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]
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
