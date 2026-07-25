import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class ArtworkWallpaperController {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]
    private var currentItem: PlayingItem?
    private var screenObserver: NSObjectProtocol?

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

    func show(_ item: PlayingItem) {
        let artworkChanged = currentItem?.artworkURL != item.artworkURL
        let metadataChanged = currentItem?.id != item.id
            || currentItem?.title != item.title
            || currentItem?.artist != item.artist
            || currentItem?.isPlaying != item.isPlaying
        currentItem = item

        if artworkChanged || windows.count != NSScreen.screens.count {
            rebuildWindows()
        } else if metadataChanged {
            updateWindowContent(with: item)
        }
    }

    func hide() {
        currentItem = nil
        closeWindows()
    }

    private func rebuildWindows() {
        closeWindows()
        guard let currentItem, currentItem.artworkURL != nil else { return }

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            let window = DesktopArtworkWindow(screen: screen)
            let hostingView = NSHostingView(
                rootView: ArtworkBackdrop(item: currentItem, showsMetadata: true)
            )
            hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
            hostingView.autoresizingMask = [.width, .height]
            window.contentView = hostingView
            window.setFrame(screen.frame, display: true)
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
        for window in windows.values {
            guard let hostingView = window.contentView as? NSHostingView<ArtworkBackdrop> else {
                continue
            }
            hostingView.rootView = ArtworkBackdrop(item: item, showsMetadata: true)
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
        hasShadow = false
        ignoresMouseEvents = true
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
