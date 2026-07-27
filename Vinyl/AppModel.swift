import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var currentItem: PlayingItem?
    @Published private(set) var isSpotifyRunning = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isWallpaperEnabled: Bool
    @Published private(set) var selectedSetupID: VinylSetup.ID = .albumCanvas

    private enum Keys {
        static let wallpaperEnabled = "Vinyl.wallpaperEnabled"
        static let hasChosenWallpaperPreference = "Vinyl.hasChosenWallpaperPreference"
        static let selectedSetup = "Vinyl.selectedSetup"
    }

    private let bridge = SpotifyBridge()
    private let wallpaper = ArtworkWallpaperController()
    private var playbackEventMonitor: SpotifyPlaybackEventMonitor?
    private var pollingTask: Task<Void, Never>?
    private var hasStarted = false

#if DEBUG
    private let isDemoMode = ProcessInfo.processInfo.arguments.contains("--demo")
#else
    private let isDemoMode = false
#endif

    init() {
        if UserDefaults.standard.bool(forKey: Keys.hasChosenWallpaperPreference) {
            isWallpaperEnabled = UserDefaults.standard.bool(forKey: Keys.wallpaperEnabled)
        } else {
            isWallpaperEnabled = true
        }

        if let savedSetup = UserDefaults.standard.string(forKey: Keys.selectedSetup),
           let setupID = VinylSetup.ID(rawValue: savedSetup),
           VinylSetup.catalogue.first(where: { $0.id == setupID })?.isAvailable == true {
            selectedSetupID = setupID
        }

        if isDemoMode {
            isSpotifyRunning = true
            currentItem = PlayingItem(
                id: "demo-track",
                title: "Desktop Preview",
                artist: "Vinyl",
                collection: "Debug build",
                artworkURL: URL(string: "https://i.scdn.co/image/ab67616d00001e02ff9ca10b55ce82ae553c8228"),
                spotifyURL: URL(string: "https://open.spotify.com"),
                isPlaying: true,
                progressMilliseconds: 74_000,
                durationMilliseconds: 208_000
            )
        }

        playbackEventMonitor = SpotifyPlaybackEventMonitor { [weak self] info in
            self?.handlePlaybackNotification(info)
        }

        start()
    }

    var statusMessage: String {
        if isDemoMode { return "Previewing the desktop artwork" }
        if !isSpotifyRunning { return "Open Spotify to get started." }
        if currentItem == nil { return "Play something in Spotify." }
        if currentItem?.isPlaying == true { return "Playing now" }
        return "Playback paused"
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        if isDemoMode {
            if isWallpaperEnabled, let currentItem {
                wallpaper.show(currentItem)
            }
            return
        }
        try? SMAppService.mainApp.register()
        startPolling()
    }

    func refresh() {
        guard !isDemoMode else { return }
        handlePlaybackNotification(nil)
    }

    func setWallpaperEnabled(_ enabled: Bool) {
        isWallpaperEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.wallpaperEnabled)
        UserDefaults.standard.set(true, forKey: Keys.hasChosenWallpaperPreference)

        if enabled, let currentItem {
            wallpaper.show(currentItem)
        } else {
            wallpaper.hide()
        }
    }

    func selectSetup(_ setup: VinylSetup) {
        guard setup.isAvailable else { return }
        selectedSetupID = setup.id
        UserDefaults.standard.set(setup.id.rawValue, forKey: Keys.selectedSetup)
    }

    private func handlePlaybackNotification(_ info: [AnyHashable: Any]?) {
        Task {
            isSpotifyRunning = bridge.isSpotifyRunning()
            guard isSpotifyRunning else {
                if currentItem != nil {
                    currentItem = nil
                    wallpaper.hide()
                }
                return
            }

            if let info, !info.isEmpty {
                let item = await bridge.playingItem(from: info)
                applyItem(item)
            }
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                isSpotifyRunning = bridge.isSpotifyRunning()
                if !isSpotifyRunning {
                    if currentItem != nil {
                        currentItem = nil
                        wallpaper.hide()
                    }
                }
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func applyItem(_ item: PlayingItem?) {
        currentItem = item
        lastUpdated = Date()
        errorMessage = nil

        if let item {
            if isWallpaperEnabled {
                wallpaper.show(item)
            }
        } else {
            wallpaper.hide()
        }
    }
}
