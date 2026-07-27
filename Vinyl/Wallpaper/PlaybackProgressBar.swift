import SwiftUI
import AppKit
import QuartzCore

/// A tiny compositor animation between synchronization points; no frame timer.
struct PlaybackProgressBar: NSViewRepresentable {
    @Environment(\.playbackRenderingSuspended) private var suspended
    let item: PlayingItem
    var color: Color = .white.opacity(0.66)
    var showsIndicator = false
    var isAdvancing: Bool? = nil

    func makeNSView(context: Context) -> PlaybackProgressHost { PlaybackProgressHost() }
    func updateNSView(_ view: PlaybackProgressHost, context: Context) {
        view.update(item:item,color:NSColor(color),suspended:suspended,
                    showsIndicator:showsIndicator,isAdvancing:isAdvancing)
    }
}

final class PlaybackProgressHost: NSView {
    private let fill = CALayer()
    private let track = CALayer()
    private let indicator = CALayer()
    private var showsIndicator = false
    private var item: PlayingItem?
    private var suspended = false
    private var isAdvancing: Bool?
    private var renderedSize = CGSize.zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        track.backgroundColor = NSColor.white.withAlphaComponent(0.13).cgColor
        layer?.addSublayer(track)
        fill.anchorPoint = .zero
        layer?.addSublayer(fill)
        layer?.addSublayer(indicator)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        guard bounds.size != renderedSize else { return }
        renderedSize = bounds.size
        render()
    }
    func update(item:PlayingItem,color:NSColor,suspended:Bool,showsIndicator:Bool = false,
                isAdvancing:Bool? = nil) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.backgroundColor = color.cgColor
        indicator.backgroundColor = color.cgColor
        indicator.shadowColor = color.cgColor
        indicator.shadowOpacity = 0.65
        indicator.shadowRadius = 3
        indicator.shadowOffset = .zero
        CATransaction.commit()
        guard self.item != item || self.suspended != suspended || self.showsIndicator != showsIndicator || self.isAdvancing != isAdvancing else { return }
        self.item = item
        self.suspended = suspended
        self.showsIndicator = showsIndicator
        self.isAdvancing = isAdvancing
        render()
    }
    private func render() {
        let duration = max(0,item?.durationMilliseconds ?? 0)
        let position = min(duration,max(0,item?.positionMilliseconds() ?? 0))
        let fraction = duration > 0 ? Double(position) / Double(duration) : 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.removeAllAnimations()
        indicator.removeAllAnimations()
        let diameter:CGFloat = showsIndicator ? min(8,bounds.height) : 0
        let inset = diameter/2
        let width = max(0,bounds.width-diameter)
        let height = showsIndicator ? min(2,bounds.height) : bounds.height
        track.frame = CGRect(x:inset,y:(bounds.height-height)/2,width:width,height:height)
        track.cornerRadius = height/2
        fill.frame = CGRect(x:inset,y:track.frame.minY,width:width*fraction,height:height)
        fill.cornerRadius = height/2
        indicator.isHidden = !showsIndicator || duration == 0
        indicator.bounds = CGRect(x:0,y:0,width:diameter,height:diameter)
        indicator.cornerRadius = diameter/2
        indicator.position = CGPoint(x:inset+width*fraction,y:bounds.height/2)
        if isAdvancing ?? (item?.isPlaying == true), !suspended, position < duration, width > 0 {
            let animation = CABasicAnimation(keyPath: "bounds.size.width")
            animation.fromValue = width * fraction
            animation.toValue = width
            animation.duration = Double(duration - position) / 1000
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            fill.bounds.size.width = width
            fill.add(animation, forKey: "vinyl.progress")
            if showsIndicator {
                let motion = CABasicAnimation(keyPath:"position.x")
                motion.fromValue = inset+width*fraction
                motion.toValue = inset+width
                motion.duration = animation.duration
                motion.timingFunction = animation.timingFunction
                indicator.position.x = inset+width
                indicator.add(motion,forKey:"vinyl.progress.indicator")
            }
        }
        CATransaction.commit()
    }
}
