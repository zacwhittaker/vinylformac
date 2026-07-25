import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
    }

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var currentItem: PlayingItem?
    @Published private(set) var statusMessage = "Connect Spotify to get started."
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

    private let clientID = SpotifyConfiguration.defaultClientID
    private let spotify = SpotifyClient()
    private let wallpaper = ArtworkWallpaperController()
    private var playbackEventMonitor: SpotifyPlaybackEventMonitor?
    private var pollingTask: Task<Void, Never>?
    private var hasStarted = false
    private var pollingDelayNanoseconds: UInt64 = 30_000_000_000
#if DEBUG
    private let isDemoMode = ProcessInfo.processInfo.arguments.contains("--demo")
#else
    private let isDemoMode = false
#endif

    init() {
        connectionState = spotify.isAuthorized(for: clientID) ? .connected : .disconnected

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
            connectionState = .connected
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
            statusMessage = "Previewing the desktop artwork"
        }

        playbackEventMonitor = SpotifyPlaybackEventMonitor { [weak self] in
            self?.refreshForLocalPlaybackEvent()
        }
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    var canConnect: Bool {
        connectionState != .connecting
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
        if isConnected {
            startPolling()
        }
    }

    func connect() {
        guard canConnect else { return }
        pollingTask?.cancel()
        connectionState = .connecting
        errorMessage = nil
        statusMessage = "Waiting for Spotify sign-in…"

        Task {
            do {
                try await spotify.connect(clientID: clientID)
                connectionState = .connected
                statusMessage = "Spotify connected."
                startPolling()
            } catch {
                connectionState = .disconnected
                statusMessage = "Spotify is not connected."
                errorMessage = error.localizedDescription
            }
        }
    }

    func disconnect() {
        pollingTask?.cancel()
        pollingTask = nil
        do {
            try spotify.disconnect()
        } catch {
            errorMessage = error.localizedDescription
        }
        connectionState = .disconnected
        currentItem = nil
        lastUpdated = nil
        statusMessage = "Spotify disconnected."
        wallpaper.hide()
    }

    func refresh() {
        guard isConnected, !isRefreshing, !isDemoMode else { return }
        Task {
            await refreshCurrentItem()
        }
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

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refreshCurrentItem()
                do {
                    try await Task.sleep(nanoseconds: pollingDelayNanoseconds)
                } catch {
                    return
                }
            }
        }
    }

    private func refreshForLocalPlaybackEvent() {
        guard isConnected, !isRefreshing, !isDemoMode else { return }
        Task {
            await refreshCurrentItem()
        }
    }

    private func refreshCurrentItem() async {
        guard isConnected else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let item = try await spotify.fetchCurrentlyPlaying(clientID: clientID)
            currentItem = item
            lastUpdated = Date()
            errorMessage = nil
            pollingDelayNanoseconds = 30_000_000_000

            if let item {
                statusMessage = item.isPlaying ? "Playing now" : "Playback paused"
                if isWallpaperEnabled {
                    wallpaper.show(item)
                }
            } else {
                statusMessage = "Nothing is playing on Spotify."
                wallpaper.hide()
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Could not refresh Spotify."
            if let spotifyError = error as? SpotifyError,
               case .rateLimited(let seconds) = spotifyError {
                let backoff = max(seconds ?? 30, 30)
                pollingDelayNanoseconds = UInt64(backoff) * 1_000_000_000
            }
        }
    }
}
