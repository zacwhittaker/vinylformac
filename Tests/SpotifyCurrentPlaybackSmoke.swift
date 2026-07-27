import Foundation

@main
struct SpotifyCurrentPlaybackSmoke {
    @MainActor
    static func main() async throws {
        let bridge = SpotifyBridge()
        guard bridge.isSpotifyRunning() else {
            print("SKIP: Spotify is not running.")
            return
        }
        switch await bridge.currentPlaybackState() {
        case .item(let item):
            precondition(!item.id.isEmpty && !item.title.isEmpty)
            precondition(item.durationMilliseconds != nil)
            print("Direct Spotify discovery passed; playing=\(item.isPlaying), position=\(item.progressMilliseconds ?? -1)ms")
        case .stopped:
            print("Direct Spotify read passed: stopped.")
        case .unavailable:
            throw NSError(domain: "Spotify direct discovery failed", code: 1)
        }
    }
}
