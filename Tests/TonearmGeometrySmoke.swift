import Foundation

@main
struct TonearmGeometrySmoke {
    static func main() {
        for scale: CGFloat in [0.5, 1, 1.5] {
            let size = CGSize(width: 1920 * scale, height: 1000 * scale)
            let diameter = min(size.height * 0.755, size.width * 0.445) * 0.98
            let record = CGRect(x: size.width * 0.345 - diameter / 2,
                                y: size.height * 0.371 - diameter * 0.76 / 2,
                                width: diameter, height: diameter * 0.76)
            let geometry = TonearmGeometry(size: size, record: record)
            let aspect = record.height / record.width
            var initialLength: CGFloat?
            var previousRadius = CGFloat.infinity
            for step in 0...100 {
                let point = geometry.contact(progress: Double(step) / 100)
                let surface = geometry.elevated(point, height: geometry.recordHeight)
                let radius = hypot((surface.x-record.midX)/(record.width/2),
                                   (surface.y-record.midY)/(record.height/2))
                precondition(radius <= 0.880001 && radius >= 0.459999, "Stylus left the playable grooves")
                precondition(radius <= previousRadius, "Stylus tracked outward")
                previousRadius = radius
                let length = hypot(point.x-geometry.pivot.x, (point.y-geometry.pivot.y)/aspect)
                if let initialLength {
                    precondition(abs(length-initialLength) < 0.0001, "Arm changed length during tracking")
                } else { initialLength = length }
                let head = geometry.elevated(point, height: geometry.armHeight)
                precondition(surface.y-head.y >= size.height*0.079, "Main tube lacks significant record clearance")
                let deckShadow = geometry.shadow(point,height:geometry.armHeight,receiver:0)
                let recordShadow = geometry.shadow(point,height:geometry.armHeight,receiver:geometry.recordHeight)
                precondition(deckShadow.y > recordShadow.y && recordShadow.y > head.y,
                             "Shadow does not follow receiver height")
            }
            // A rest target may not shorten the arm. Check the entire swing,
            // including intermediate animation frames, in the record plane.
            for step in 0...40 {
                let angle=geometry.angle(progress:0.5,engagement:Double(step)/40)
                let contact=geometry.ground(CGPoint(x:geometry.length,y:0),angle:angle)
                let head=geometry.ground(geometry.shellLocal,angle:angle)
                precondition(hypot(head.x-contact.x,head.y-contact.y)<0.00001,
                             "Stylus protrudes horizontally beyond the cartridge")
                let distance=hypot(contact.x-geometry.pivot.x,(contact.y-geometry.pivot.y)/aspect)
                precondition(abs(distance-geometry.length)<0.0001,"Arm shortened while parking")
                for index in 1..<80 {
                    func projected(_ i: Int) -> CGPoint {
                        let t = CGFloat(i)/80
                        return geometry.elevated(geometry.ground(geometry.tubePoint(at:t),angle:angle),
                                                 height:geometry.height(at:t,lift:1-Double(step)/40))
                    }
                    let p=projected(index-1), q=projected(index), r=projected(index+1)
                    precondition((q.x-p.x)*(r.y-q.y)-(q.y-p.y)*(r.x-q.x) > -0.00001,
                                 "Projected tube develops a second bend")
                }
                let a=geometry.ground(geometry.tubePoint(at:0.25),angle:angle)
                let b=geometry.ground(geometry.tubePoint(at:0.75),angle:angle)
                let span=hypot(a.x-b.x,(a.y-b.y)/aspect)
                let localA=geometry.tubePoint(at:0.25),localB=geometry.tubePoint(at:0.75)
                precondition(abs(span-hypot(localA.x-localB.x,localA.y-localB.y))<0.0001,"single bow deformed during swing")
            }
            // A single bow has no inflection: successive tangents turn in
            // one direction. This catches the rejected S silhouette.
            var previousTurn: CGFloat = 0
            for step in 1..<100 {
                let a = geometry.tubePoint(at: CGFloat(step-1)/100)
                let b = geometry.tubePoint(at: CGFloat(step)/100)
                let c = geometry.tubePoint(at: CGFloat(step+1)/100)
                let turn = (b.x-a.x)*(c.y-b.y)-(b.y-a.y)*(c.x-b.x)
                precondition(turn > -0.00001, "Tube reverses curvature")
                previousTurn += turn
            }
            precondition(previousTurn > 0 && geometry.tubePoint(at:0.5).y < -geometry.length*0.15,
                         "Tube lost its broad single bow")
            let lead = geometry.tubePoint(at:geometry.tubeLeadFraction)
            for step in 1..<10 {
                let point = geometry.tubePoint(at:geometry.tubeLeadFraction*CGFloat(step)/10)
                precondition(abs(point.x*lead.y-point.y*lead.x) < 0.00001,
                             "Tube curves inside the bearing collar")
            }
            let parkedEnd=geometry.elevated(geometry.rest,height:geometry.recordHeight+geometry.cueHeight)
            // Inspect the actual sampled stroke at lift=0, as the app draws
            // parked arms. The old test used lift=1 and missed the live error.
            let cup = geometry.elevated(geometry.restGround,height:geometry.restHeight)
            let supportY = cup.y-geometry.unit*0.002
            let points = (0...80).map { i in
                let t = CGFloat(i)/80
                return geometry.elevated(geometry.ground(geometry.tubePoint(at:t),angle:geometry.parkedAngle),
                                         height:geometry.height(at:t,lift:0))
            }
            let crossings = zip(points,points.dropFirst()).compactMap { a,b -> CGFloat? in
                guard a.y <= supportY && b.y >= supportY && b.y > a.y else { return nil }
                return a.x+(b.x-a.x)*(supportY-a.y)/(b.y-a.y)
            }
            let fixedPedestal=geometry.ground(geometry.restLocal,angle:geometry.pedestalAngle)
            precondition(abs(geometry.restGround.x-(fixedPedestal.x+geometry.pedestalXOffset)) < 0.0001 &&
                         abs(geometry.restGround.y-(fixedPedestal.y+geometry.unit*0.002)) < 0.0001,
                         "Pedestal anchor changed with the tonearm parked angle")
            precondition(crossings.contains { abs($0-cup.x) < 0.1*scale },
                         "Lowered rendered wire misses fixed cup center: \(crossings), target \(cup.x)")
            precondition(parkedEnd.x < size.width*0.95 && parkedEnd.y < size.height*0.56,
                         "Parked stylus overlaps display or leaves deck x=\(parkedEnd.x) y=\(parkedEnd.y) angle=\(geometry.parkedAngle)")
            // The rest now lives beside the card, under the tube terminus.
            // Check its complete foot and cartridge width, not an old Y limit.
            let platterDiameter=diameter/0.98
            let cardWidth=size.width*0.275, cardHeight=cardWidth*250/910
            let nearestY=max(size.height*0.555-cardHeight/2, size.height*0.402)
            let ellipseY=(nearestY-size.height*0.402)/(platterDiameter*0.875/2)
            let platterRight=size.width*0.345+platterDiameter*1.105/2*sqrt(max(0,1-ellipseY*ellipseY))
            let deckRight=size.width*(0.915+(0.555-0.055)/(0.752-0.055)*0.035)
            let cardRight=(platterRight+deckRight)/2+cardWidth/2
            precondition(geometry.restGround.x-size.height*0.016 > cardRight+size.height*0.006,
                         "Cradle foot overlaps display")
            let shell=geometry.elevated(geometry.ground(geometry.shellLocal,angle:geometry.parkedAngle),height:geometry.headshellHeight)
            precondition(abs(shell.x-points.last!.x)<0.0001 && shell.y>points.last!.y,
                         "Parked cartridge is not upright below the terminal")
            for i in 0...10 {
                let t=1-geometry.tubeTailFraction*CGFloat(i)/10
                let point=geometry.elevated(geometry.ground(geometry.tubePoint(at:t),angle:geometry.parkedAngle),height:geometry.height(at:t,lift:0))
                precondition(abs(point.x-shell.x)<0.0001,"Tube keeps bending after the cradle")
            }
        }
        // Sweep through the old 45-degree shading flip and all other angles.
        for band in 0...24 {
            var previous: Double?
            for step in 0...3600 {
                let angle = Double(step)*Double.pi/1800
                let normal = CGVector(dx:-sin(angle),dy:cos(angle))
                let value = TonearmMetalLighting.brightness(across:Double(band)/12-1,normal:normal)
                if let previous { precondition(abs(value-previous)<0.003,"Counterweight highlight jumps") }
                previous = value
            }
        }
        print("Tonearm geometry smoke test passed: grooves, rigid single bow and parking swing, significant height, receiver shadows and display clearance.")
    }
}
