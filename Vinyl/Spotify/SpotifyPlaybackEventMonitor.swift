import Foundation

@MainActor
final class SpotifyPlaybackEventMonitor {
    private static let playbackStateChanged = Notification.Name(
        "com.spotify.client.PlaybackStateChanged"
    )

    private var observer: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?
    private let onPlaybackChange: @MainActor ([AnyHashable: Any]) -> Void

    init(onPlaybackChange: @escaping @MainActor ([AnyHashable: Any]) -> Void) {
        self.onPlaybackChange = onPlaybackChange
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.playbackStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo ?? [:]
            Task { @MainActor in
                self?.scheduleRefresh(info)
            }
        }
    }

    deinit {
        debounceTask?.cancel()
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    private func scheduleRefresh(_ info: [AnyHashable: Any]) {
        debounceTask?.cancel()
        let captured = info
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            onPlaybackChange(captured)
        }
    }
}
