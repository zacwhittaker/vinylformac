import Foundation

@main struct PlayerConfigurationSmoke {
    @MainActor static func main() throws {
        let suite = "Vinyl.PlayerSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var old = AppConfiguration()
        old.globalAppearance.theme = .walnut
        old.globalAppearance.lightingIntensity = 0.37
        old.displayConfigurations["screen"] = .init(id: "screen", enabled: false, sceneExposure: 0.27, appearance: .init(theme: .aurora))
        old.animations.idleDelay = 36
        let encoder = JSONEncoder()
        defaults.set(try encoder.encode(old), forKey: "Vinyl.configuration.v2")
        defaults.set(try encoder.encode([AppearancePreset(name: "Old", appearance: .init(theme: .walnut))]), forKey: "Vinyl.presets.v1")
        let store = ConfigurationStore(defaults: defaults)
        precondition(store.configuration.musicPlayer == .spotify)
        precondition(store.presets.map(\.name) == ["Midnight"])
        precondition(ThemeChoice.all.map(\.id) == ["turntable.midnight"])
        precondition(store.configuration.globalAppearance.rendererTheme == .midnight)
        precondition(store.configuration.globalAppearance.lightingIntensity == 0.37)
        precondition(store.configuration.appearance(for: "screen").rendererTheme == .midnight)
        precondition(!store.configuration.isEnabled(displayID: "screen"))
        precondition(store.configuration.sceneExposure(for: "screen") == 0.27)
        precondition(store.configuration.animations.idleDelay == 36)
        store.configuration.musicPlayer = .appleMusic
        let restored = ConfigurationStore(defaults: defaults)
        precondition(restored.configuration.musicPlayer == .appleMusic)
        precondition(restored.presets == store.presets)
        var next = restored.configuration
        next.musicPlayer = .spotify
        precondition(restored.configuration.differsOnlyInAppearance(from: next), "Player selection alone must not recreate windows")
        print("Player configuration passed: Midnight migration, preserved calibration/motion, source default and persistence")
    }
}
