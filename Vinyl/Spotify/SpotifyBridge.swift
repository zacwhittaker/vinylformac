import AppKit
import Foundation

@MainActor
final class SpotifyBridge {
    enum CurrentPlaybackState {
        case item(PlayingItem)
        case stopped
        case unavailable
    }
    private struct OEmbedResponse: Decodable {
        let thumbnailURL: URL

        private enum CodingKeys: String, CodingKey {
            case thumbnailURL = "thumbnail_url"
        }
    }

    private var artworkCache: [String: URL] = [:]
    private let scripts = SpotifyScriptExecutor()

    func isSpotifyRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
    }

    enum Command { case previous, playPause, next }

    /// Uses Spotify's public AppleScript dictionary. Keeping commands behind this
    /// bridge means another playback provider can supply the same actions later.
    @discardableResult
    func perform(_ command: Command) async -> Bool {
        guard isSpotifyRunning() else { return false }
        let verb = switch command {
        case .previous: "previous track"
        case .playPause: "playpause"
        case .next: "next track"
        }
        return await scripts.execute("tell application \"Spotify\" to \(verb)") != nil
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

        let artworkURL = artworkCache[trackID]
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
        guard case .item(let item) = await currentPlaybackState() else { return nil }
        return item
    }

    func currentPlaybackState() async -> CurrentPlaybackState {
        guard isSpotifyRunning() else { return .unavailable }
        let script = """
        set AppleScript's text item delimiters to ASCII character 31
        tell application "Spotify"
            set stateText to (player state as text)
            if stateText is "stopped" then return stateText
            set activeTrack to current track
            set artURL to ""
            try
                set artURL to artwork url of activeTrack
            end try
            return {stateText, name of activeTrack as text, artist of activeTrack as text, album of activeTrack as text, spotify url of activeTrack as text, duration of activeTrack as text, player position as text, artURL} as text
        end tell
        """
        guard let values = await scripts.execute(script) else { return .unavailable }
        if values.first?.lowercased() == "stopped" { return .stopped }
        guard values.count >= 7 else { return .unavailable }
        let trackID=values[4]
        return .item(PlayingItem(
            id:trackID.isEmpty ? "spotify-current-\(values[1])-\(values[2])":trackID,
            title:values[1],artist:values[2],collection:values[3],
            artworkURL:values.count > 7 ? URL(string: values[7]) : artworkCache[trackID],spotifyURL:Self.webURL(from:trackID),
            isPlaying:values[0].lowercased() == "playing",
            progressMilliseconds:Int((Double(values[6].replacingOccurrences(of: ",", with: ".")) ?? 0)*1000),
            durationMilliseconds:Int(values[5])
        ))
    }

    func fetchArtworkURL(trackID: String) async -> URL? {
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
            if artworkCache.count >= 100 { artworkCache.removeAll(keepingCapacity: true) }
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

/// Serial executor keeps Apple Events off the UI thread and prevents overlapping reads.
@MainActor
private final class SpotifyScriptExecutor {
    private var cache: [String: CompiledSpotifyScript] = [:]
    private let queue = DispatchQueue(label: "Vinyl.Spotify", qos: .userInitiated)

    func execute(_ source: String) async -> [String]? {
        let compiled: CompiledSpotifyScript
        if let cached = cache[source] {
            compiled = cached
        } else {
            guard let script = NSAppleScript(source: "with timeout of 3 seconds\n" + source + "\nend timeout") else { return nil }
            // Resolve Spotify's scripting dictionary on the app's main run loop
            // once. Execution is serialized on the background queue below.
            var error: NSDictionary?
            guard script.compileAndReturnError(&error) else { return nil }
            compiled = CompiledSpotifyScript(script)
            cache[source] = compiled
        }
        return await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let result = compiled.script.executeAndReturnError(&error)
                guard error == nil else {
                    NSLog("Spotify read failed: %@", error!)
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (result.stringValue ?? "").components(separatedBy: "\u{1F}"))
            }
        }
    }
}

/// Compiled on the main actor, then accessed only by the executor's serial queue.
private final class CompiledSpotifyScript: @unchecked Sendable {
    let script: NSAppleScript
    init(_ script: NSAppleScript) { self.script = script }
}
