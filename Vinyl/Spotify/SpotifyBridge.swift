import AppKit
import Foundation

final class SpotifyBridge: @unchecked Sendable {
    private var artworkCache: [String: URL] = [:]

    func isSpotifyRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
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

    private func fetchArtworkURL(trackID: String) async -> URL? {
        guard !trackID.isEmpty else { return nil }
        if let cached = artworkCache[trackID] { return cached }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = Self.fetchArtworkSync(trackID: trackID)
                if let result { self?.artworkCache[trackID] = result }
                continuation.resume(returning: result)
            }
        }
    }

    private static func fetchArtworkSync(trackID: String) -> URL? {
        let encoded = trackID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackID
        let oembedURL = "https://open.spotify.com/oembed?url=\(encoded)"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-s", "-m", "5", oembedURL]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let thumbnail = json["thumbnail_url"] as? String else {
            return nil
        }

        // Upgrade from 300px to 640px and use stable i.scdn.co domain
        let upgraded = thumbnail
            .replacingOccurrences(
                of: "image-cdn-[a-z]+\\.spotifycdn\\.com",
                with: "i.scdn.co",
                options: .regularExpression
            )
            .replacingOccurrences(of: "ab67616d00001e02", with: "ab67616d0000b273")

        return URL(string: upgraded)
    }

    private static func webURL(from uri: String) -> URL? {
        let parts = uri.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        let type = parts[1]
        let id = parts[2]
        return URL(string: "https://open.spotify.com/\(type)/\(id)")
    }
}
