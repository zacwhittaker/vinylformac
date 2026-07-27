import AppKit
import Foundation

@MainActor private final class PlayerStub: DesktopMusicProvider {
    var reads = 0
    var pending: CheckedContinuation<SpotifyBridge.CurrentPlaybackState, Never>?
    var result: SpotifyBridge.CurrentPlaybackState
    var suspend = false
    init(_ item: PlayingItem) { result = .item(item) }
    func isRunning() -> Bool { true }
    func currentPlaybackState() async -> SpotifyBridge.CurrentPlaybackState {
        reads += 1
        if suspend {
            suspend = false
            return await withCheckedContinuation { pending = $0 }
        }
        return result
    }
    func perform(_ command: SpotifyBridge.Command) async -> Bool { true }
}

@main struct PlayerSwitchSmoke {
    @MainActor static func main() async throws {
        let suite = "Vinyl.SwitchSmoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var configuration = AppConfiguration(); configuration.startEnabled = false
        defaults.set(try JSONEncoder().encode(configuration), forKey: "Vinyl.configuration.v2")
        let spotifyItem = PlayingItem(id: "spotify-track", title: "Spotify", artist: "Test", collection: nil,
                                     artworkURL: nil, spotifyURL: nil, isPlaying: true,
                                     progressMilliseconds: 1000, durationMilliseconds: 200000)
        var musicItem = spotifyItem
        musicItem = PlayingItem(id: "music-track", title: "Music", artist: "Test", collection: nil,
                                artworkURL: nil, spotifyURL: nil, isPlaying: true,
                                progressMilliseconds: 2000, durationMilliseconds: 200000, source: .appleMusic)
        let spotify = PlayerStub(spotifyItem); spotify.suspend = true
        let music = PlayerStub(musicItem)
        let model = AppModel(defaults: defaults, spotify: spotify, music: music)
        for _ in 0..<100 where spotify.pending == nil { try await Task.sleep(for: .milliseconds(10)) }
        precondition(spotify.pending != nil)
        model.selectPlayer(.appleMusic)
        precondition(model.currentItem == nil)
        spotify.pending?.resume(returning: .item(spotifyItem)); spotify.pending = nil
        for _ in 0..<100 where model.currentItem?.source != .appleMusic { try await Task.sleep(for: .milliseconds(10)) }
        precondition(model.currentItem?.id == "music-track", "Old provider overwrote the newly selected source")
        precondition(model.configurationStore.configuration.musicPlayer == .appleMusic)
        let paused = PlayingItem(id: "paused-spotify", title: "Paused", artist: "Test", collection: nil,
                                 artworkURL: nil, spotifyURL: nil, isPlaying: false,
                                 progressMilliseconds: 1000, durationMilliseconds: 200000)
        spotify.result = .item(paused)
        let reads = spotify.reads
        model.selectPlayer(.spotify)
        for _ in 0..<100 where spotify.reads == reads { try await Task.sleep(for: .milliseconds(10)) }
        try await Task.sleep(for: .milliseconds(30))
        precondition(model.currentItem == nil, "Paused source must start at the idle turntable")
        spotify.result = .item(spotifyItem); model.refresh()
        for _ in 0..<100 where model.currentItem == nil { try await Task.sleep(for: .milliseconds(10)) }
        precondition(model.currentItem?.id == "spotify-track")
        print("Player switching passed: late read rejected, selected source persisted, paused source idle, playing source resumes")
    }
}
