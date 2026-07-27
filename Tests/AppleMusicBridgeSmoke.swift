import AppKit
import Foundation

@main struct AppleMusicBridgeSmoke {
    @MainActor static func main() {
        let fields = ["playing", "Title\u{1F}with separator", "Artist", "Album", "ABC123", "240,75", "82.5"]
        guard case .item(let item) = AppleMusicBridge.decode(fields, sampledAt: 100) else { fatalError("Missing track") }
        precondition(item.source == .appleMusic && item.id == "appleMusic:ABC123" && item.spotifyURL == nil)
        precondition(item.durationMilliseconds == 240750 && item.progressMilliseconds == 82500)
        precondition(item.positionMilliseconds(at: 102) == 84500)
        var pausedFields = fields; pausedFields[0] = "paused"
        guard case .item(let paused) = AppleMusicBridge.decode(pausedFields, sampledAt: 100) else { fatalError() }
        precondition(!paused.isPlaying && paused.positionMilliseconds(at: 105) == 82500)
        var gate = StartupPlaybackGate()
        precondition(gate.accept(paused) == nil && gate.accept(item) == item)
        guard case .stopped = AppleMusicBridge.decode(["stopped"]) else { fatalError() }
        guard case .unavailable = AppleMusicBridge.decode(["playing"]) else { fatalError() }
        var stream = fields; stream[4] = ""; stream[5] = "NaN"; stream[6] = "-1"
        guard case .item(let radio) = AppleMusicBridge.decode(stream) else { fatalError() }
        precondition(radio.durationMilliseconds == nil && radio.progressMilliseconds == nil)
        // Compile against the installed Music dictionary; never execute or alter playback.
        for source in [AppleMusicBridge.metadataScript, AppleMusicBridge.artworkScript,
                       "tell application id \"com.apple.Music\" to playpause",
                       "tell application id \"com.apple.Music\" to previous track",
                       "tell application id \"com.apple.Music\" to next track"] {
            let script = NSAppleScript(source: source)!
            var error: NSDictionary?
            precondition(script.compileAndReturnError(&error), "Script failed: \(String(describing: error))")
        }
        print("Apple Music passed: metadata/units, paused/idle gating, malformed/stream fields and all scripts compile")
    }
}
