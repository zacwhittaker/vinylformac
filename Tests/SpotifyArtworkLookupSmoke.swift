import Foundation

@main
struct SpotifyArtworkLookupSmoke {
    @MainActor
    static func main() async throws {
        let bridge = SpotifyBridge()
        let item = await bridge.playingItem(from: [
            "Player State": "Playing",
            "Name": "Cut To The Feeling",
            "Artist": "Carly Rae Jepsen",
            "Album": "Cut To The Feeling",
            "Track ID": "spotify:track:11dFghVXANMlKmJXsNCbNl",
            "Duration": 207_959,
            "Playback Position": 0.0
        ])

        guard let artworkURL = item?.artworkURL,
              artworkURL.host == "i.scdn.co" else {
            throw SmokeError.artworkURLMissing
        }

        let (data, response) = try await URLSession.shared.data(from: artworkURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              !data.isEmpty else {
            throw SmokeError.artworkDownloadFailed
        }

        print("Spotify artwork lookup smoke test passed.")
    }
}

private enum SmokeError: Error {
    case artworkURLMissing
    case artworkDownloadFailed
}
