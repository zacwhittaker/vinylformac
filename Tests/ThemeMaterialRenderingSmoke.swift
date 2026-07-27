import AppKit
import SwiftUI

@MainActor
private final class MaterialSelection: ObservableObject {
    @Published var materials = MidnightMaterials.make()
}

private struct RetainedMaterialArm: View {
    @ObservedObject var selection: MaterialSelection
    let item: PlayingItem
    var body: some View {
        MidnightTonearm(progress:0.4,playing:true,enabled:true,reduceMotion:false,
                        recordSurface:CGRect(x:145,y:42,width:370,height:281),accent:.cyan,
                        itemID:item.id,positionMilliseconds:item.progressMilliseconds,
                        durationMilliseconds:item.durationMilliseconds,sampledAt:item.sampledAt,
                        restoresPlaybackState:true)
            .environment(\.turntableMaterials,selection.materials)
            .frame(width:960,height:500)
    }
}

@main
struct ThemeMaterialRenderingSmoke {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        var variant = MidnightMaterials.make()
        variant.chassisTop = .init(colors:[.red,.red,.red],finish:.smooth)
        variant.tonearm.metalTint = SIMD3(1,0.6,0.2)
        variant.tonearm.headshell = [.orange,.brown,.black]

        func pixels(_ material: TurntableSurface) -> NSBitmapImageRep {
            let renderer = ImageRenderer(content:RoundedRectangle(cornerRadius:12)
                .fill(material.gradient(from:.topLeading,to:.bottomTrailing))
                .turntableFinish(material,size:CGSize(width:64,height:64))
                .frame(width:64,height:64))
            renderer.scale = 1
            return NSBitmapImageRep(cgImage:renderer.cgImage!)
        }
        // No Metal bundle is required: this verifies pigment flow and the
        // alpha-preserving material tint branch independently of shader lookup.
        let neutral = pixels(.init(colors:[.white],finish:.smooth))
        let tinted = pixels(.init(colors:[.white],finish:.smooth,tint:.red))
        let changed = pixels(variant.chassisTop)
        let a = neutral.colorAt(x:32,y:32)!.usingColorSpace(.deviceRGB)!
        let b = tinted.colorAt(x:32,y:32)!.usingColorSpace(.deviceRGB)!
        let c = changed.colorAt(x:32,y:32)!.usingColorSpace(.deviceRGB)!
        precondition(a.greenComponent > 0.9 && b.redComponent > b.greenComponent * 2 && c.redComponent > c.greenComponent * 2,
                     "Material pigment was not applied: \(a), \(b), \(c)")
        for y in 0..<64 { for x in 0..<64 {
            precondition(abs(neutral.colorAt(x:x,y:y)!.alphaComponent-tinted.colorAt(x:x,y:y)!.alphaComponent)<0.001,
                         "Material tint changed the silhouette alpha")
        }}
        let selection = MaterialSelection()
        let item = PlayingItem(id:"theme-switch",title:"Theme",artist:"Test",collection:nil,
                               artworkURL:nil,spotifyURL:nil,isPlaying:true,
                               progressMilliseconds:40_000,durationMilliseconds:100_000)
        var phases = [String](), angles = [Double]()
        TonearmAnimationDiagnostics.didEnterPhase = { phases.append($0) }
        TonearmAnimationDiagnostics.didDraw = { angles.append($0) }
        let host = NSHostingView(rootView:RetainedMaterialArm(selection:selection,item:item))
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:960,height:500),styleMask:[.borderless],backing:.buffered,defer:false)
        window.contentView = host
        window.orderFrontRegardless()
        var sampleCountBefore = 0
        DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
            precondition(!angles.isEmpty,"Playing arm did not render")
            phases.removeAll()
            sampleCountBefore = angles.count
            selection.materials = variant
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+1.2) {
            precondition(angles.count > sampleCountBefore,"Material update stopped live tracking")
            precondition(phases.isEmpty,"Material update restarted physical choreography: \(phases)")
            precondition(abs(angles.last!-angles.first!) < 1,"Material update jumped the arm pose")
            selection.materials = MidnightMaterials.make()
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+1.8) {
            precondition(phases.isEmpty,"Restoring Midnight restarted choreography")
            print("Theme material rendering passed: pigment, alpha preservation and retained playing arm across material changes")
            window.close()
            exit(0)
        }
        app.run()
    }
}
