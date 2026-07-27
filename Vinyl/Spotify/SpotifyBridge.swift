import AppKit
import Foundation

@MainActor
final class SpotifyBridge {
    private struct OEmbedResponse: Decodable {
        let thumbnailURL: URL

        private enum CodingKeys: String, CodingKey {
            case thumbnailURL = "thumbnail_url"
        }
    }

    private var artworkCache: [String: URL] = [:]

    func isSpotifyRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
    }

    enum Command { case previous, playPause, next }

    /// Uses Spotify's public AppleScript dictionary. Keeping commands behind this
    /// bridge means another playback provider can supply the same actions later.
    @discardableResult
    func perform(_ command: Command) -> Bool {
        guard isSpotifyRunning() else { return false }
        let verb = switch command {
        case .previous: "previous track"
        case .playPause: "playpause"
        case .next: "next track"
        }
        var error: NSDictionary?
        NSAppleScript(source: "tell application \"Spotify\" to \(verb)")?
            .executeAndReturnError(&error)
        return error == nil
    }

    func playingItem(from userInfo: [AnyHashable: Any]) async -> PlayingItem? {
        let playerState = userInfo["Player State"] as? String ?? ""
        guard playerState != "Stopped" else { return nil }

        let name = userInfo["Name"] as? String ?? ""
        let artist = userInfo["Artist"] as? String ?? ""
        let album = userInfo["Album"] as? String ?? ""
        let trackID = userInfo["Track ID"] as? String ?? ""
        let duration = userInfo["Duration"] as? Int ?? 0
        let position = userInfo["Playback Position"] as? Double ?? 0
        let isPlaying = playerState == "Playing"

        let artworkURL = await fetchArtworkURL(trackID: trackID)
        let spotifyURL = Self.webURL(from: trackID)

        return PlayingItem(
            id: trackID,
            title: name,
            artist: artist,
            collection: album,
            artworkURL: artworkURL,
            spotifyURL: spotifyURL,
            isPlaying: isPlaying,
            progressMilliseconds: Int(position * 1000),
            durationMilliseconds: duration
        )
    }

    /// Reads the current player state directly so launch does not depend on a
    /// future distributed notification from Spotify.
    func currentPlayingItem() async -> PlayingItem? {
        guard isSpotifyRunning() else { return nil }
        let separator = "\u{1F}"
        let script = """
        tell application "Spotify"
            set stateText to (player state as text)
            if stateText is "stopped" then return stateText
            set activeTrack to current track
            return stateText & "(separator)" & (name of activeTrack) & "(separator)" & (artist of activeTrack) & "(separator)" & (album of activeTrack) & "(separator)" & (spotify url of activeTrack) & "(separator)" & (duration of activeTrack as text) & "(separator)" & (player position as text)
        end tell
        """
        var error:NSDictionary?
        guard let result=NSAppleScript(source:script)?.executeAndReturnError(&error).stringValue,
              error == nil else { return nil }
        let values=result.components(separatedBy:separator)
        guard values.count >= 7,values[0].lowercased() != "stopped" else { return nil }
        let trackID=values[4]
        return PlayingItem(
            id:trackID.isEmpty ? "spotify-current-\(values[1])-\(values[2])":trackID,
            title:values[1],artist:values[2],collection:values[3],
            artworkURL:await fetchArtworkURL(trackID:trackID),spotifyURL:Self.webURL(from:trackID),
            isPlaying:values[0].lowercased() == "playing",
            progressMilliseconds:Int((Double(values[6]) ?? 0)*1000),
            durationMilliseconds:Int(values[5])
        )
    }

    private func fetchArtworkURL(trackID: String) async -> URL? {
        guard !trackID.isEmpty else { return nil }
        if let cached = artworkCache[trackID] { return cached }

        guard var components = URLComponents(string: "https://open.spotify.com/oembed") else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "url", value: trackID)]
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let payload = try JSONDecoder().decode(OEmbedResponse.self, from: data)
            let artworkURL = Self.upgradedArtworkURL(from: payload.thumbnailURL)
            artworkCache[trackID] = artworkURL
            return artworkURL
        } catch {
            return nil
        }
    }

    private static func upgradedArtworkURL(from thumbnailURL: URL) -> URL {
        // Upgrade from 300px to 640px and use stable i.scdn.co domain
        let upgraded = thumbnailURL.absoluteString
            .replacingOccurrences(
                of: "image-cdn-[a-z]+\\.spotifycdn\\.com",
                with: "i.scdn.co",
                options: .regularExpression
            )
            .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273")

        return URL(string: upgraded) ?? thumbnailURL
    }

    private static func webURL(from uri: String) -> URL? {
        let parts = uri.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        let type = parts[1]
        let id = parts[2]
        return URL(string: "https://open.spotify.com/\(type)/\(id)")
    }
}
