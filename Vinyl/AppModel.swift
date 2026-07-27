import Foundation
import ServiceManagement
import Combine
import AppKit

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
    private var consecutiveStoppedReads = 0
    private var consecutiveUnavailableReads = 0
    private var hasStarted = false
    private var refreshTask: Task<Void, Never>?
    private var refreshPending = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var sleeping = false
    private var restoreWallpaperAfterWake = false
    private var startupPlaybackGate = StartupPlaybackGate()
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
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   app.bundleIdentifier != "com.spotify.client" { return }
                Task { @MainActor in
                    guard let self else { return }
                    self.refresh()
                    self.startPolling()
                }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(center.addObserver(forName:name, object:nil, queue:.main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.sleeping else { return }
                    let interruptedRefresh = self.refreshTask
                    interruptedRefresh?.cancel()
                    self.sleeping = false
                    self.restoreWallpaperAfterWake = true
                    if let interruptedRefresh { await interruptedRefresh.value }
                    guard !self.sleeping else { return }
                    self.refresh()
                    self.startPolling()
                }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.sleeping = true
                    self.restoreWallpaperAfterWake = false
                    self.pollingTask?.cancel()
                    self.refreshTask?.cancel()
                    self.wallpaper.hide()
                }
            })
        }
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
        guard !sleeping else { return }
        refreshPending = true
        guard refreshTask == nil else { return }
        refreshTask = Task {
            isRefreshing = true
            defer { isRefreshing = false; refreshTask = nil; startPolling() }
            repeat {
                refreshPending = false
                isSpotifyRunning = bridge.isSpotifyRunning()
                guard isSpotifyRunning else {
                    consecutiveUnavailableReads = 0
                    consecutiveStoppedReads = 0
                    if currentItem != nil || restoreWallpaperAfterWake { applyItem(nil) }
                    return
                }
                let result = await bridge.currentPlaybackState()
                guard !Task.isCancelled, !sleeping else { return }
                // An event received during a read makes that response obsolete.
                if refreshPending { continue }
                switch result {
                case .item(let item):
                    consecutiveStoppedReads = 0
                    consecutiveUnavailableReads = 0
                    applyItem(startupPlaybackGate.accept(item))
                case .stopped:
                    consecutiveUnavailableReads = 0
                    consecutiveStoppedReads += 1
                    if consecutiveStoppedReads >= 2 { applyItem(nil) }
                    else {
                        try? await Task.sleep(for: .milliseconds(350))
                        refreshPending = true
                    }
                case .unavailable:
                    consecutiveUnavailableReads = min(consecutiveUnavailableReads + 1, 4)
                    errorMessage = "Couldn’t read Spotify. Check Vinyl’s Automation access in System Settings."
                    restoreWallpaperIfNeeded(using: currentItem)
                }
            } while refreshPending && !Task.isCancelled
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        guard !sleeping, isSpotifyRunning else { return }
        let interval: Double
        if consecutiveUnavailableReads > 0 {
            interval = min(30, pow(2, Double(consecutiveUnavailableReads)))
        } else if currentItem != nil {
            // Spotify does not reliably notify position-only seeks, including
            // while paused. Read the authoritative position in both states.
            interval = 0.5
        } else if currentItem == nil && consecutiveStoppedReads < 2 {
            interval = 2
        } else {
            // Paused/stopped playback has no polling task. Spotify events,
            // activation, wake and manual refresh restart synchronization.
            return
        }
        pollingTask = Task {
            do {
                try await Task.sleep(for: .seconds(interval), tolerance: .milliseconds(100))
                guard !Task.isCancelled else { return }
                refresh()
            } catch {
                return
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

        if restoreWallpaperIfNeeded(using:item) { return }

        if let item {
            if isWallpaperEnabled && !sleeping {
                wallpaper.show(item, configuration: configurationStore.configuration)
            }
        } else {
            if isWallpaperEnabled { wallpaper.show(.idle, configuration: configurationStore.configuration) }
        }
    }

    @discardableResult
    private func restoreWallpaperIfNeeded(using item: PlayingItem?) -> Bool {
        guard restoreWallpaperAfterWake else { return false }
        restoreWallpaperAfterWake = false
        if isWallpaperEnabled {
            wallpaper.restore(item ?? .idle, configuration: configurationStore.configuration)
        }
        return true
    }

    func applyPreset(_ preset: AppearancePreset) {
        configurationStore.configuration.globalAppearance = preset.appearance
    }

    private func sendPlaybackCommand(_ command: SpotifyBridge.Command) {
        Task {
            guard await bridge.perform(command) else { return }
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
