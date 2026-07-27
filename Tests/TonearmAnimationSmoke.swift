import AppKit
import SwiftUI

@main
struct TonearmAnimationSmoke {
    @MainActor static func main() {
        let app=NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let size=CGSize(width:960,height:500)
        let record=CGRect(x:145,y:42,width:370,height:281)
        let duration=100_000
        func item(position:Int,playing:Bool)->PlayingItem {
            PlayingItem(id:"test",title:"Test",artist:"Test",collection:nil,artworkURL:nil,
                        spotifyURL:nil,isPlaying:playing,progressMilliseconds:position,
                        durationMilliseconds:duration,sampledAt:ProcessInfo.processInfo.systemUptime)
        }
        var phases=[String]()
        var mechanismEvents=[Bool]()
        var currentPhase=""
        var pauseAngles=[Double]()
        TonearmAnimationDiagnostics.didDraw={ angle in
            if currentPhase == "liftingRecord" || currentPhase == "hoveringRecord" {
                pauseAngles.append(angle)
            }
        }
        var travelLevels=[Double]()
        var parkedRenderCount=0
        var lastDrawnPose="none"
        TonearmAnimationDiagnostics.didDrawTube={ points,cup,engagement,lift in
            lastDrawnPose="\(currentPhase): engagement=\(engagement), lift=\(lift)"
            // The completed lowering frame and parked frame are visually
            // identical; SwiftUI may reuse that Canvas without drawing again.
            guard (currentPhase == "parked" || currentPhase == "loweringToPedestal"),
                  engagement == 0, lift == 0 else { return }
            let crossings = zip(points,points.dropFirst()).compactMap { a,b -> CGFloat? in
                guard a.y <= cup.y && b.y >= cup.y && b.y > a.y else { return nil }
                return a.x+(b.x-a.x)*(cup.y-a.y)/(b.y-a.y)
            }
            precondition(crossings.contains { abs($0-cup.x)<0.1 },"Rendered parked wire misses cradle: \(crossings) versus \(cup.x)")
            parkedRenderCount += 1
        }
        TonearmAnimationDiagnostics.didDrawBearingGap={ gap in
            precondition(gap < 0.001,"Tube detached from bearing: \(gap)")
        }
        TonearmAnimationDiagnostics.didEnterPhase={ value in
            currentPhase=value
            phases.append(value)
        }
        TonearmAnimationDiagnostics.didDrawPose={ _,lift,_ in
            if currentPhase == "travellingToRecord" { travelLevels.append(lift) }
        }
        let first=item(position:10_000,playing:true)
        func arm(_ value:PlayingItem)->AnyView {
            AnyView(MidnightTonearm(progress:value.progress ?? 0,playing:value.isPlaying,enabled:true,
                reduceMotion:false,recordSurface:record,accent:.red,itemID:value.id,
                positionMilliseconds:value.progressMilliseconds,durationMilliseconds:value.durationMilliseconds,
                sampledAt:value.sampledAt,onPlaybackMechanismChanged:{ mechanismEvents.append($0) }))
        }
        let host=NSHostingView(rootView:arm(first))
        host.frame=CGRect(origin:.zero,size:size)
        let window=NSWindow(contentRect:CGRect(origin:CGPoint(x:-4000,y:-4000),size:size),
                            styleMask:.borderless,backing:.buffered,defer:false)
        window.contentView=host
        window.orderFrontRegardless()
        func snapshot(_ name: String) {
            guard let prefix=ProcessInfo.processInfo.environment["VINYL_TONEARM_SNAPSHOT_PREFIX"],
                  let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds) else { return }
            host.cacheDisplay(in:host.bounds,to:bitmap)
            guard let data=bitmap.representation(using:.png,properties:[:]) else { return }
            try! data.write(to:URL(fileURLWithPath:"\(prefix)-\(name).png"))
        }
        let renderTimer = Timer.scheduledTimer(withTimeInterval:1.0/60.0,repeats:true) { _ in
            host.display()
        }
        _ = renderTimer

        // Authoritative position refreshes during cueing must retarget the
        // existing transfer, not inject a second record-side lift.
        DispatchQueue.main.asyncAfter(deadline:.now()+0.25) {
            host.rootView=arm(item(position:20_000,playing:true))
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.8) {
            host.rootView=arm(item(position:30_000,playing:true))
        }

        DispatchQueue.main.asyncAfter(deadline:.now()+0.2) {
            precondition(!mechanismEvents.contains(true),"Record started before stylus contact")
            precondition(phases.contains("liftingPedestal"),"Start did not lift from the pedestal")
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+5.5) {
            let expected=["liftingPedestal","raisedPedestal","travellingToRecord",
                          "positionedAboveRecord","loweringToRecord","tracking"]
            let distinct = phases.reduce(into:[String]()) { if $0.last != $1 { $0.append($1) } }
            precondition(distinct == expected,"Start sequence repeated or omitted a physical phase: \(phases)")
            precondition(travelLevels.count > 5,"Insufficient rendered travel samples")
            precondition((travelLevels.max() ?? 0)-(travelLevels.min() ?? 0) < 0.001,
                         "Cue height changed during lateral travel: \(travelLevels)")
            precondition(mechanismEvents.last == true,"Record did not start after stylus contact")
            phases.removeAll(); mechanismEvents.removeAll()
            snapshot("playing")
            host.rootView=arm(item(position:12_200,playing:false))
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+6.4) {
            precondition(pauseAngles.count > 5,"Missing pause render samples")
            precondition((pauseAngles.max() ?? 0)-(pauseAngles.min() ?? 0) < 0.001,
                         "Pause changed groove instead of lifting in place: \(pauseAngles)")
            precondition(mechanismEvents.last == false,"Pause did not stop the platter immediately")
            precondition(phases.contains("liftingRecord") && phases.contains("hoveringRecord"),
                         "Pause did not lift before waiting: \(phases)")
            precondition(!phases.contains("travellingToPedestal"),"Arm parked before the 15-second deadline")
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+15.0) {
            precondition(!phases.contains("travellingToPedestal"),"Arm parked before 10 paused seconds")
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+18.5) {
            let expected=["liftingRecord","hoveringRecord","travellingToPedestal","loweringToPedestal","parked"]
            precondition(expected.allSatisfy(phases.contains),"Paused parking sequence omitted a physical phase: \(phases)")
            precondition(parkedRenderCount > 0,"No fully lowered parked frames were checked; last draw \(lastDrawnPose)")
            snapshot("parked")
            phases.removeAll(); mechanismEvents.removeAll(); travelLevels.removeAll()
            host.rootView=arm(item(position:90_000,playing:true))
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+23.0) {
            let expected=["liftingPedestal","raisedPedestal","travellingToRecord",
                          "positionedAboveRecord","loweringToRecord","tracking"]
            let distinct=phases.reduce(into:[String]()) { if $0.last != $1 { $0.append($1) } }
            precondition(distinct == expected,"Parked resume sequence changed: \(phases)")
            precondition(travelLevels.count > 5 && (travelLevels.max() ?? 0)-(travelLevels.min() ?? 0)<0.001,
                         "Parked resume did not retain full lift while travelling")
            precondition(mechanismEvents.last == true,"Inner-groove resume did not finish lowering")
            snapshot("inner")
            print("Tonearm animation passed: rigid attachment, ordered resume, lift in place, contact gating, 10-second parking and rendered cradle centering.")
            exit(0)
        }
        app.run()
    }
}
