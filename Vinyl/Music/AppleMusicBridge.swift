import AppKit
import CryptoKit
import Foundation

/// Local Music.app integration. Uses its installed scripting dictionary, not
/// MusicKit credentials or a second audio player.
@MainActor
final class AppleMusicBridge {
    private let executor = MusicScriptExecutor()
    private var cachedTrackID: String?
    private var cachedArtworkURL: URL?
    private var nextArtworkAttempt: TimeInterval = 0

    func isRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
    }

    func perform(_ command: SpotifyBridge.Command) async -> Bool {
        guard isRunning() else { return false }
        let verb = switch command {
        case .previous: "previous track"
        case .playPause: "playpause"
        case .next: "next track"
        }
        return await executor.execute("tell application id \"com.apple.Music\" to \(verb)") != nil
    }

    func currentPlaybackState() async -> SpotifyBridge.CurrentPlaybackState {
        guard isRunning(), let result = await executor.execute(Self.metadataScript) else { return .unavailable }
        let sampledAt = ProcessInfo.processInfo.systemUptime
        guard case .item(let metadata) = Self.decode(result.strings, sampledAt: sampledAt) else {
            return Self.decode(result.strings, sampledAt: sampledAt)
        }
        if cachedTrackID != metadata.id {
            cachedTrackID = metadata.id
            cachedArtworkURL = nil
            nextArtworkAttempt = 0
        }
        if cachedArtworkURL == nil, sampledAt >= nextArtworkAttempt {
            nextArtworkAttempt = sampledAt + 5
            if let artwork = await executor.execute(Self.artworkScript),
               Self.identity(artwork.strings) == metadata.id,
               let data = artwork.artwork, !data.isEmpty {
                cachedArtworkURL = await Self.storeArtwork(data)
            }
        }
        // Keep the metadata's sample clock: fetching artwork takes time.
        return Self.decode(result.strings, artworkURL: cachedArtworkURL, sampledAt: sampledAt)
    }

    static func identity(_ values: [String]) -> String? {
        guard values.count >= 5 else { return nil }
        let stable = values[4].isEmpty ? values[1...3].joined(separator: "|") : values[4]
        return "appleMusic:" + stable
    }

    static func decode(_ values: [String], artworkURL: URL? = nil,
                       sampledAt: TimeInterval = ProcessInfo.processInfo.systemUptime) -> SpotifyBridge.CurrentPlaybackState {
        guard let state = values.first?.lowercased() else { return .unavailable }
        if state == "stopped" { return .stopped }
        guard ["playing", "paused", "fast forwarding", "rewinding"].contains(state),
              values.count >= 7, let id = identity(values), !values[1].isEmpty else { return .unavailable }
        func milliseconds(_ text: String) -> Int? {
            guard let seconds = Double(text.replacingOccurrences(of: ",", with: ".")),
                  seconds.isFinite, seconds >= 0, seconds < Double(Int.max / 1000) else { return nil }
            return Int(seconds * 1000)
        }
        return .item(PlayingItem(id: id, title: values[1], artist: values[2], collection: values[3],
                                artworkURL: artworkURL, spotifyURL: nil, isPlaying: state == "playing",
                                progressMilliseconds: milliseconds(values[6]), durationMilliseconds: milliseconds(values[5]),
                                source: .appleMusic, sampledAt: sampledAt))
    }

    // Lists avoid delimiter collisions in titles. Optional fields can be absent
    // for streams; a stopped player must never ask for a nonexistent track.
    static let metadataScript = """
    tell application id "com.apple.Music"
        set stateText to player state as text
        if stateText is "stopped" then return {stateText}
        set activeTrack to current track
        set trackID to ""
        set artistText to ""
        set albumText to ""
        set durationText to ""
        set positionText to ""
        try
            set trackID to persistent ID of activeTrack as text
        end try
        try
            set artistText to artist of activeTrack as text
            set albumText to album of activeTrack as text
        end try
        try
            set durationText to duration of activeTrack as text
            set positionText to player position as text
        end try
        return {stateText, name of activeTrack as text, artistText, albumText, trackID, durationText, positionText}
    end tell
    """

    static let artworkScript = """
    tell application id "com.apple.Music"
        set activeTrack to current track
        set trackID to ""
        set artistText to ""
        set albumText to ""
        try
            set trackID to persistent ID of activeTrack as text
        end try
        try
            set artistText to artist of activeTrack as text
            set albumText to album of activeTrack as text
        end try
        return {"artwork", name of activeTrack as text, artistText, albumText, trackID, raw data of artwork 1 of activeTrack}
    end tell
    """

    private static func storeArtwork(_ data: Data) async -> URL? {
        await Task.detached(priority: .utility) {
            guard data.count <= 20 * 1024 * 1024 else { return nil }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VinylMusicArtwork", isDirectory: true)
            let name = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let url = directory.appendingPathComponent(name + ".artwork")
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: url.path) { try data.write(to: url, options: .atomic) }
                let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
                    .filter { $0.pathExtension == "artwork" && $0 != url }
                    .sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                        > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
                for old in files.dropFirst(15) { try? FileManager.default.removeItem(at: old) }
                return url
            } catch { return nil }
        }.value
    }
}

private struct MusicScriptResult: Sendable {
    let strings: [String]
    let artwork: Data?
}

@MainActor
private final class MusicScriptExecutor {
    private var cache: [String: CompiledMusicScript] = [:]
    private let queue = DispatchQueue(label: "Vinyl.AppleMusic", qos: .userInitiated)

    func execute(_ source: String) async -> MusicScriptResult? {
        let compiled: CompiledMusicScript
        if let existing = cache[source] { compiled = existing }
        else {
            guard let script = NSAppleScript(source: "with timeout of 3 seconds\n" + source + "\nend timeout") else { return nil }
            var error: NSDictionary?
            guard script.compileAndReturnError(&error) else { return nil }
            compiled = CompiledMusicScript(script)
            cache[source] = compiled
        }
        return await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let result = compiled.script.executeAndReturnError(&error)
                guard error == nil else { continuation.resume(returning: nil); return }
                let count = result.numberOfItems
                let strings = count > 0 ? (1...count).map { result.atIndex($0)?.stringValue ?? "" } : []
                let artwork = strings.first == "artwork" && count == 6 ? result.atIndex(6)?.data : nil
                continuation.resume(returning: MusicScriptResult(strings: strings, artwork: artwork))
            }
        }
    }
}

private final class CompiledMusicScript: @unchecked Sendable {
    let script: NSAppleScript
    init(_ script: NSAppleScript) { self.script = script }
}
