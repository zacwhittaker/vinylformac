import Foundation

@main
struct StartupPlaybackGateSmoke {
    static func main() {
        let paused = item(id: "paused", playing: false)
        let playing = item(id: "playing", playing: true)
        var gate = StartupPlaybackGate()

        precondition(gate.accept(nil) == nil, "Unavailable startup must remain idle")
        precondition(gate.accept(paused) == nil, "Paused startup must remain idle")
        precondition(!gate.hasConfirmedPlaying, "Paused state must not unlock startup")
        precondition(gate.accept(playing) == playing, "Confirmed playing state must be accepted")
        precondition(gate.hasConfirmedPlaying, "Playing state must unlock normal transport")
        precondition(gate.accept(paused) == paused, "Pause after playback must use normal behavior")

        print("Startup playback gate passed")
    }

    private static func item(id: String, playing: Bool) -> PlayingItem {
        PlayingItem(
            id: id, title: id, artist: "Vinyl", collection: nil,
            artworkURL: nil, spotifyURL: nil, isPlaying: playing,
            progressMilliseconds: 1_000, durationMilliseconds: 10_000
        )
    }
}
