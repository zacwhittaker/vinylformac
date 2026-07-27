import SwiftUI
import AppKit
import QuartzCore

struct SpinningArtwork: View {
    let url: URL?
    let startingAngle: Double
    let isPlaying: Bool
    let fallback: Color
    @State private var displayed: CGImage?
    @Environment(\.playbackRenderingSuspended) private var suspended
    @Environment(\.playbackMotionReduced) private var reduced

    var body: some View {
        ArtworkRotationLayer(image: url.flatMap { ArtworkImageCache.shared.cached($0) } ?? displayed,
                             startingAngle: startingAngle, isPlaying: isPlaying && !suspended && !reduced,
                             fallback: NSColor(fallback))
            .task(id: url) {
                guard let url else { displayed = nil; return }
                let image = await ArtworkImageCache.shared.image(for: url)
                guard !Task.isCancelled, let image else { return }
                displayed = image
            }
    }
}

struct ArtworkRotationLayer: NSViewRepresentable {
    let image: CGImage?
    let startingAngle: Double
    let isPlaying: Bool
    let fallback: NSColor
    func makeNSView(context: Context) -> ArtworkRotationHost {
        ArtworkRotationHost(startingAngle: startingAngle)
    }
    func updateNSView(_ view: ArtworkRotationHost, context: Context) {
        view.update(image: image, fallback: fallback, playing: isPlaying)
    }
    static func dismantleNSView(_ view: ArtworkRotationHost, coordinator: ()) { view.setPlaying(false) }
}

/// The image is an immutable texture. Only this CALayer's transform animates;
/// AppKit never owns or adjusts its anchor point or its presentation transform.
final class ArtworkRotationHost: NSView {
    let artworkLayer = CALayer()
    private var angle: Double
    private var playing = false
    private var requested = false
    private var currentImage: CGImage?
    init(startingAngle: Double) {
        angle = startingAngle * .pi / 180
        super.init(frame: .zero)
        wantsLayer = true
        artworkLayer.contentsGravity = .resizeAspectFill
        artworkLayer.masksToBounds = true
        artworkLayer.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        artworkLayer.borderWidth = 0.8
        artworkLayer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        layer?.addSublayer(artworkLayer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artworkLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        artworkLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        artworkLayer.cornerRadius = min(bounds.width, bounds.height) / 2
        artworkLayer.contentsScale = window?.backingScaleFactor ?? 2
        CATransaction.commit()
    }
    func update(image: CGImage?, fallback: NSColor, playing: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if currentImage !== image {
            currentImage = image
            artworkLayer.contents = image
        }
        artworkLayer.backgroundColor = fallback.cgColor
        CATransaction.commit()
        setPlaying(playing)
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateAnimation() }
    func setPlaying(_ value: Bool) { requested = value; updateAnimation() }
    private func updateAnimation() {
        let next = requested && window != nil
        guard next != playing else { return }
        if playing, let value = artworkLayer.presentation()?.value(forKeyPath: "transform.rotation.z") as? Double { angle = value }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artworkLayer.removeAnimation(forKey: "vinyl.rotation")
        artworkLayer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        if next {
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = angle
            animation.toValue = angle + 2 * .pi
            animation.duration = 12
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            let rate = Float(window?.screen?.maximumFramesPerSecond ?? 60)
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, rate), maximum: rate, preferred: rate)
            artworkLayer.add(animation, forKey: "vinyl.rotation")
        }
        CATransaction.commit()
        playing = next
    }
}
