import SwiftUI

private struct PlaybackRenderingSuspendedKey: EnvironmentKey {
    static let defaultValue = false
}
private struct PlaybackMotionReducedKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var playbackMotionReduced: Bool {
        get { self[PlaybackMotionReducedKey.self] }
        set { self[PlaybackMotionReducedKey.self] = newValue }
    }
    var playbackRenderingSuspended: Bool {
        get { self[PlaybackRenderingSuspendedKey.self] }
        set { self[PlaybackRenderingSuspendedKey.self] = newValue }
    }
}

/// Wake at the playback clock's second boundary. Paused text has no timer.
struct PlaybackTextSchedule: TimelineSchedule {
    let item: PlayingItem
    var paused = false
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        guard item.isPlaying && !paused else { return AnySequence([startDate]) }
        let milliseconds = item.positionMilliseconds()
        let next = Date().addingTimeInterval(Double(1000 - milliseconds % 1000) / 1000 + 0.008)
        return AnySequence(sequence(first: startDate) { previous in
            previous == startDate ? max(next, startDate.addingTimeInterval(0.008)) : previous.addingTimeInterval(1)
        })
    }
}
