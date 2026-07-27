import Foundation
import ServiceManagement
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var currentItem: PlayingItem?
    @Published private(set) var isSpotifyRunning = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isWallpaperEnabled: Bool
    @Published private(set) var selectedSetupID: VinylSetup.ID = .albumCanvas
    let configurationStore = ConfigurationStore()
    let displayManager = DisplayManager()
    let animationCoordinator = PlaybackAnimationCoordinator()

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
    private var cancellables: Set<AnyCancellable> = []

#if DEBUG
    private let isDemoMode = ProcessInfo.processInfo.arguments.contains("--demo")
#else
    private let isDemoMode = false
#endif

    init() {
        if UserDefaults.standard.bool(forKey: Keys.hasChosenWallpaperPreference) {
            isWallpaperEnabled = UserDefaults.standard.bool(forKey: Keys.wallpaperEnabled)
        } else {
            isWallpaperEnabled = configurationStore.configuration.startEnabled
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
        wallpaper.setPlaybackActions(PlaybackActions(
            previous: { [weak self] in self?.sendPlaybackCommand(.previous) },
            playPause: { [weak self] in self?.sendPlaybackCommand(.playPause) },
            next: { [weak self] in self?.sendPlaybackCommand(.next) }
        ))

        for display in displayManager.displays { configurationStore.ensureDisplay(display.id) }
        configurationStore.$configuration
            .dropFirst()
            .sink { [weak self] configuration in
                guard let self else { return }
                self.wallpaper.update(configuration: configuration)
                self.updateLaunchAtLogin(configuration.launchAtLogin)
            }
            .store(in: &cancellables)
        displayManager.$displays
            .dropFirst()
            .sink { [weak self] displays in
                guard let self else { return }
                for display in displays { self.configurationStore.ensureDisplay(display.id) }
                self.wallpaper.update(configuration: self.configurationStore.configuration)
            }
            .store(in: &cancellables)
        displayManager.$identificationVisible
            .dropFirst()
            .sink { [weak self] visible in self?.wallpaper.setIdentificationVisible(visible) }
            .store(in: &cancellables)

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
                wallpaper.show(currentItem, configuration: configurationStore.configuration)
            }
            return
        }
        updateLaunchAtLogin(configurationStore.configuration.launchAtLogin)
        // The wallpaper is a persistent desktop object, not a playback-event
        // notification. Put the idle turntable on every enabled display before
        // Spotify discovery begins so launch never presents an empty desktop.
        if isWallpaperEnabled {
            wallpaper.show(currentItem ?? .idle, configuration: configurationStore.configuration)
        }
        handlePlaybackNotification(nil)
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

        if enabled {
            wallpaper.show(currentItem ?? .idle, configuration: configurationStore.configuration)
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
                }
                if isWallpaperEnabled { wallpaper.show(.idle, configuration: configurationStore.configuration) }
                return
            }

            if let info, !info.isEmpty {
                let item = await bridge.playingItem(from: info)
                applyItem(item)
            } else {
                applyItem(await bridge.currentPlayingItem())
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
                    }
                    if isWallpaperEnabled { wallpaper.show(.idle, configuration: configurationStore.configuration) }
                } else if currentItem == nil || currentItem?.isPlaying == true {
                    applyItem(await bridge.currentPlayingItem())
                }
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func applyItem(_ item: PlayingItem?) {
        let previousItem = currentItem
        currentItem = item
        animationCoordinator.consume(
            previous: previousItem,
            current: item,
            style: configurationStore.configuration.animations.style
        )
        lastUpdated = Date()
        errorMessage = nil

        if let item {
            if isWallpaperEnabled {
                wallpaper.show(item, configuration: configurationStore.configuration)
            }
        } else {
            if isWallpaperEnabled { wallpaper.show(.idle, configuration: configurationStore.configuration) }
        }
    }

    func applyPreset(_ preset: AppearancePreset) {
        configurationStore.configuration.globalAppearance = preset.appearance
    }

    private func sendPlaybackCommand(_ command: SpotifyBridge.Command) {
        guard bridge.perform(command) else { return }
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            refresh()
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
#if !DEBUG
        if enabled, SMAppService.mainApp.status == .notRegistered { try? SMAppService.mainApp.register() }
        if !enabled, SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
#endif
    }
}
