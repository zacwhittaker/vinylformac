import Foundation

@MainActor
protocol DesktopMusicProvider: AnyObject {
    func isRunning() -> Bool
    func currentPlaybackState() async -> SpotifyBridge.CurrentPlaybackState
    func perform(_ command: SpotifyBridge.Command) async -> Bool
}

extension SpotifyBridge: DesktopMusicProvider {
    func isRunning() -> Bool { isSpotifyRunning() }
}
extension AppleMusicBridge: DesktopMusicProvider {}
