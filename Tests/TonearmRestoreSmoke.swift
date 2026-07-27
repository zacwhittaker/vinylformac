import AppKit
import SwiftUI

@main
struct TonearmRestoreSmoke {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let size = CGSize(width: 960, height: 500)
        let record = CGRect(x: 145, y: 42, width: 370, height: 281)
        var phases = [String]()
        var mechanisms = [Bool]()
        TonearmAnimationDiagnostics.didEnterPhase = { phases.append($0) }

        func arm(id: String, playing: Bool) -> MidnightTonearm {
            MidnightTonearm(
                progress: 0.42, playing: playing, enabled: true, reduceMotion: false,
                recordSurface: record, accent: .white, itemID: id,
                positionMilliseconds: 42_000, durationMilliseconds: 100_000,
                sampledAt: ProcessInfo.processInfo.systemUptime,
                restoresPlaybackState: true,
                onPlaybackMechanismChanged: { mechanisms.append($0) }
            )
        }

        let root = HStack(spacing: 0) {
            arm(id: "wake-playing", playing: true)
            arm(id: "wake-paused", playing: false)
        }
        let host = NSHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -4000, y: -4000), size: size),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        window.contentView = host
        window.orderFrontRegardless()
        host.display()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            precondition(phases.contains("tracking"), "Playing wake did not restore directly to tracking: \(phases)")
            precondition(phases.contains("parked"), "Paused wake did not restore directly to the pedestal: \(phases)")
            let transient = phases.filter { $0 != "tracking" && $0 != "parked" }
            precondition(transient.isEmpty, "Wake replayed a physical sequence: \(transient)")
            precondition(mechanisms.contains(true) && mechanisms.contains(false),
                         "Restored platter state did not match playback: \(mechanisms)")
            print("Tonearm restore passed: playing joins tracking and paused joins parked without transition phases.")
            exit(0)
        }
        app.run()
    }
}
