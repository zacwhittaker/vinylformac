import Foundation

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

    var progress: Double? {
        guard let progressMilliseconds,
              let durationMilliseconds,
              durationMilliseconds > 0 else {
            return nil
        }
        return min(max(Double(progressMilliseconds) / Double(durationMilliseconds), 0), 1)
    }
}
