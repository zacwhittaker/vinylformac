import Foundation

@main
struct SpotifyPlaybackEventMonitorSmoke {
    @MainActor
    static func main() async throws {
        var refreshCount = 0
        let monitor = SpotifyPlaybackEventMonitor {
            refreshCount += 1
        }

        DistributedNotificationCenter.default().post(
            name: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        try await Task.sleep(nanoseconds: 600_000_000)
        guard refreshCount == 1 else {
            withExtendedLifetime(monitor) {}
            throw SmokeError.eventNotReceived
        }

        withExtendedLifetime(monitor) {}
        print("Spotify playback event monitor smoke test passed.")
    }
}

private enum SmokeError: Error {
    case eventNotReceived
}
