import AppKit
import SwiftUI
import QuartzCore

@MainActor
final class FrameProbe: NSObject {
    var samples: [Double] = []
    var angles: [Double] = []
    weak var layer: CALayer?
    @objc func tick(_ link: CADisplayLink) {
        samples.append(link.timestamp)
        if let value = layer?.presentation()?.value(forKeyPath: "transform.rotation.z") as? Double {
            angles.append(value)
        }
    }
}

@main
struct PlaybackRenderingSmoke {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: CGRect(x: 20, y: 20, width: 180, height: 180),
                              styleMask: .borderless, backing: .buffered, defer: false)
        let host = ArtworkRotationHost(startingAngle: 0)
        window.contentView = host
        window.orderFrontRegardless()
        host.setPlaying(true)
        let originalHost = host.artworkLayer
        let probe = FrameProbe()
        probe.layer = host.artworkLayer
        let link = window.displayLink(target: probe, selector: #selector(FrameProbe.tick(_:)))
        link.add(to: .main, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            precondition(host.artworkLayer.animation(forKey: "vinyl.rotation") != nil)
            let distinct = Set(probe.angles.map { Int($0 * 10_000) }).count
            precondition(distinct > 30, "Rotation did not advance through compositor frames")
            let intervals = zip(probe.samples.dropFirst(), probe.samples).map { $0 - $1 }.filter { $0 > 0 }
            let median = intervals.sorted()[intervals.count / 2]
            print("Display-link median cadence: \(Int((1 / median).rounded()))Hz; \(distinct) distinct presentation angles")
            host.setPlaying(false)
            precondition(host.artworkLayer === originalHost, "Pause replaced the artwork host")
            precondition(host.artworkLayer.animation(forKey: "vinyl.rotation") == nil)
            let paused = host.artworkLayer.transform
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                precondition(CATransform3DEqualToTransform(paused, host.artworkLayer.transform))
                host.setPlaying(true)
                precondition(host.artworkLayer === originalHost, "Resume replaced the artwork host")
                precondition(host.artworkLayer.animation(forKey: "vinyl.rotation") != nil)
                link.invalidate()
                window.orderOut(nil)
                print("Persistent artwork host, compositor rotation, pause and resume passed.")
                exit(0)
            }
        }
        app.run()
    }
}
