import AppKit
import QuartzCore

@main
struct PlaybackProgressSmoke {
    @MainActor static func main() {
        let host = PlaybackProgressHost(frame:NSRect(x:0,y:0,width:200,height:10))
        func item(_ position:Int, playing:Bool = false) -> PlayingItem {
            PlayingItem(id:"test",title:"Test",artist:"Test",collection:nil,
                        artworkURL:nil,spotifyURL:nil,isPlaying:playing,
                        progressMilliseconds:position,durationMilliseconds:100_000)
        }
        func update(_ value:PlayingItem, suspended:Bool = false) {
            host.update(item:value,color:.systemPink,suspended:suspended,showsIndicator:true)
        }
        update(item(25_000))
        let layers = host.layer!.sublayers!
        let track=layers[0], fill=layers[1], dot=layers[2]
        func aligned() {
            precondition(abs(dot.position.x-fill.frame.maxX)<0.01)
            precondition(dot.frame.minX >= 0 && dot.frame.maxX <= host.bounds.width)
        }
        aligned()
        precondition(fill.bounds.width == 48 && dot.position.x == 52)
        precondition(fill.backgroundColor == dot.backgroundColor)
        update(item(0)); aligned()
        update(item(100_000)); aligned()
        update(item(75_000)); aligned()
        host.frame.size.width=320
        host.layout()
        aligned()
        precondition(track.bounds.width == 312)
        update(item(20_000,playing:true))
        let growth=fill.animation(forKey:"vinyl.progress") as! CABasicAnimation
        let motion=dot.animation(forKey:"vinyl.progress.indicator") as! CABasicAnimation
        precondition(growth.duration == motion.duration)
        precondition(abs((motion.fromValue as! Double)-(growth.fromValue as! Double)-4)<0.01)
        update(item(30_000,playing:true),suspended:true)
        precondition(fill.animationKeys()?.isEmpty ?? true)
        precondition(dot.animationKeys()?.isEmpty ?? true)
        aligned()
        update(item(30_000)); aligned()
        update(.idle)
        precondition(dot.isHidden && fill.bounds.width == 0)
        print("Progress passed: colour, endpoints, seek, resize, paired animation, suspension, pause and idle reset.")
    }
}
