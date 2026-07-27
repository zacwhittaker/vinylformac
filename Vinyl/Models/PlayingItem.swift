import Foundation

enum PlaybackSource: String, Codable {
    case spotify
    case appleMusic
    case unknown
}

struct PlayingItem: Equatable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let collection: String?
    let artworkURL: URL?
    let spotifyURL: URL?
    let isPlaying: Bool
    let progressMilliseconds: Int?
    let durationMilliseconds: Int?
    var source: PlaybackSource = .spotify
    var sampledAt: TimeInterval = ProcessInfo.processInfo.systemUptime

    func positionMilliseconds(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int {
        let elapsed = isPlaying ? max(0, uptime - sampledAt) : 0
        return min(max(0, (progressMilliseconds ?? 0) + Int(elapsed * 1000)),
                   max(0, durationMilliseconds ?? Int.max))
    }

    static let idle = PlayingItem(
        id: "vinyl-idle", title: "Music Not Playing", artist: "Vinyl is ready", collection: nil,
        artworkURL: nil, spotifyURL: nil, isPlaying: false,
        progressMilliseconds: nil, durationMilliseconds: nil, source: .unknown
    )

    var albumIdentity: String {
        [artist, collection ?? "", artworkURL?.absoluteString ?? ""].joined(separator: "|")
    }

    var progress: Double? {
        guard let progressMilliseconds,
              let durationMilliseconds,
              durationMilliseconds > 0 else {
            return nil
        }
        return min(max(Double(progressMilliseconds) / Double(durationMilliseconds), 0), 1)
    }
}

struct StartupPlaybackGate {
    private(set) var hasConfirmedPlaying = false

    mutating func accept(_ item: PlayingItem?) -> PlayingItem? {
        guard !hasConfirmedPlaying else { return item }
        guard let item, item.isPlaying else { return nil }
        hasConfirmedPlaying = true
        return item
    }
}
