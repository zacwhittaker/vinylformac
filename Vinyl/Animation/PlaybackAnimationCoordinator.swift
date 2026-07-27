import Foundation

enum PlaybackVisualState: Equatable {
    case idle, starting, playing, pausing, paused, resuming, stopping
    case changingTrack(sameAlbum: Bool)
    case seeking
}

@MainActor
final class PlaybackAnimationCoordinator: ObservableObject {
    @Published private(set) var state: PlaybackVisualState = .idle
    private var convergenceTask: Task<Void, Never>?

    func consume(previous: PlayingItem?, current: PlayingItem?, style: AnimationStyle) {
        convergenceTask?.cancel()
        let target: PlaybackVisualState
        switch (previous, current) {
        case (nil, .some(let item)): target = item.isPlaying ? .starting : .paused
        case (.some, nil): target = .stopping
        case (.some(let old), .some(let new)) where old.id != new.id:
            target = .changingTrack(sameAlbum: old.albumIdentity == new.albumIdentity)
        case (.some(let old), .some(let new)) where old.isPlaying != new.isPlaying:
            target = new.isPlaying ? .resuming : .pausing
        case (.some(let old), .some(let new)) where abs((old.progress ?? 0) - (new.progress ?? 0)) > 0.08:
            target = .seeking
        default: target = current?.isPlaying == true ? .playing : .paused
        }
        state = target

        let delay: Duration = switch (target, style) {
        case (.changingTrack(let sameAlbum), _): .milliseconds(sameAlbum ? 450 : (style == .physical ? 2_200 : 800))
        case (.stopping, _): .milliseconds(1_600)
        case (_, .minimal): .milliseconds(120)
        default: .milliseconds(850)
        }
        convergenceTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            state = current?.isPlaying == true ? .playing : (current == nil ? .idle : .paused)
        }
    }
}
