import Foundation

@MainActor
final class SpotifyPlaybackEventMonitor {
    private static let playbackStateChanged = Notification.Name(
        "com.spotify.client.PlaybackStateChanged"
    )

    private var observer: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?
    private let onPlaybackChange: @MainActor () -> Void

    init(onPlaybackChange: @escaping @MainActor () -> Void) {
        self.onPlaybackChange = onPlaybackChange
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.playbackStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleRefresh()
            }
        }
    }

    deinit {
        debounceTask?.cancel()
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func scheduleRefresh() {
        debounceTask?.cancel()
        debounceTask = Task {
            do {
                // Spotify can emit a short burst while changing tracks.
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            onPlaybackChange()
        }
    }
}
