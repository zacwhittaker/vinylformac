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
