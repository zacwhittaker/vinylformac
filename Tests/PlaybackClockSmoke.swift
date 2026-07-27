import Foundation

@main
struct PlaybackClockSmoke {
    static func main() {
        let playing = PlayingItem(id: "test", title: "Test", artist: "Test",
                                  collection: nil, artworkURL: nil, spotifyURL: nil,
                                  isPlaying: true, progressMilliseconds: 10_000,
                                  durationMilliseconds: 60_000, sampledAt: 100)
        precondition(playing.positionMilliseconds(at: 105.25) == 15_250)
        precondition(playing.positionMilliseconds(at: 200) == 60_000)
        precondition(playing.positionMilliseconds(at: 99) == 10_000)
        let paused = PlayingItem(id: "test", title: "Test", artist: "Test",
                                 collection: nil, artworkURL: nil, spotifyURL: nil,
                                 isPlaying: false, progressMilliseconds: 15_250,
                                 durationMilliseconds: 60_000, sampledAt: 105.25)
        precondition(paused.positionMilliseconds(at: 200) == 15_250)
        let seek = PlayingItem(id: "test", title: "Test", artist: "Test",
                               collection: nil, artworkURL: nil, spotifyURL: nil,
                               isPlaying: true, progressMilliseconds: 2_000,
                               durationMilliseconds: 60_000, sampledAt: 110)
        precondition(seek.positionMilliseconds(at: 111) == 3_000)
        print("Playback clock: elapsed time, pause, seek and bounds passed.")
    }
}
