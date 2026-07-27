import Foundation
import SwiftUI

@main
struct PlaybackScheduleSmoke {
    static func main() {
        let item = PlayingItem(id:"test",title:"test",artist:"test",collection:nil,artworkURL:nil,spotifyURL:nil,
                               isPlaying:true,progressMilliseconds:10_950,durationMilliseconds:100_000)
        let now = Date()
        let entries = Array(PlaybackTextSchedule(item:item).entries(from:now,mode:.normal).prefix(3))
        precondition(entries.count == 3)
        precondition(entries[1].timeIntervalSince(now) < 0.15, "Clock waited a full second near a playback boundary")
        precondition(abs(entries[2].timeIntervalSince(entries[1]) - 1) < 0.001)
        let suspended = Array(PlaybackTextSchedule(item:item,paused:true).entries(from:now,mode:.normal))
        precondition(suspended.count == 1, "Invisible content kept scheduling ticks")
        let paused = PlayingItem(id:"test",title:"test",artist:"test",collection:nil,artworkURL:nil,spotifyURL:nil,
                                 isPlaying:false,progressMilliseconds:10_950,durationMilliseconds:100_000)
        precondition(Array(PlaybackTextSchedule(item:paused).entries(from:now,mode:.normal)).count == 1)
        print("Playback scheduling passed: next-second alignment and no paused/hidden ticks.")
    }
}
