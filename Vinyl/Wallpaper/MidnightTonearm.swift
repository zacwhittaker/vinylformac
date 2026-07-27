import SwiftUI


#if DEBUG
enum TonearmAnimationDiagnostics {
    static var didDraw: ((Double) -> Void)?
    static var didDrawPose: ((Double, Double, CGFloat) -> Void)?
    static var didDrawBearingGap: ((CGFloat) -> Void)?
    static var didDrawTube: (([CGPoint], CGPoint, Double, Double) -> Void)?
    static var didEnterPhase: ((String) -> Void)?
}
#endif

private struct TonearmTimelineSchedule: TimelineSchedule {
    let playing: Bool
    let active: Bool
    let reduceMotion: Bool
    let sampledAt: TimeInterval?

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        guard active, !reduceMotion else { return AnySequence([startDate]) }
        if playing {
            return AnySequence(sequence(first:startDate) { $0.addingTimeInterval(1.0/30.0) })
        }
        return AnySequence(sequence(first:startDate) { $0.addingTimeInterval(0.25) })
    }
}

/// Ground coordinates, object elevation and the record's receiving surface are
/// separate. All three still pass through the deck's existing camera projection.
struct MidnightTonearm: View {
    static let pauseRestDelay: TimeInterval = 10
    static let liftDuration: TimeInterval = 0.45
    static let travelDuration: TimeInterval = 1.15
    static let parkDuration: TimeInterval = 0.95
    static let pedestalLowerDuration: TimeInterval = 0.35
    let progress: Double
    let playing: Bool
    let enabled: Bool
    let reduceMotion: Bool
    let recordSurface: CGRect
    let accent: Color
    var itemID: String = ""
    var positionMilliseconds: Int? = nil
    var durationMilliseconds: Int? = nil
    var sampledAt: TimeInterval? = nil
    var idleDelay: TimeInterval = 10
    var restoresPlaybackState = false
    var onPlaybackMechanismChanged: (Bool) -> Void = { _ in }
    @State private var phase: Phase = .parked
    @State private var sequenceTask: Task<Void, Never>?
    @State private var motionComplete = true
    @State private var latestInput: Input?
    @State private var retargetAfterTravel = false
    @State private var segmentStart = 0.0
    @State private var segmentDuration = 0.0
    @State private var fromPose = SIMD3<Double>(0,0,0)
    @State private var toPose = SIMD3<Double>(0,0,0)
    @State private var eventPose: SIMD3<Double>?

    private enum Phase: Equatable {
        case parked, liftingPedestal, raisedPedestal, travellingToRecord, positionedAboveRecord, loweringToRecord
        case tracking, liftingRecord, hoveringRecord, travellingToPedestal, loweringToPedestal

        var engagement: Double {
            switch self {
            case .parked, .liftingPedestal, .raisedPedestal, .travellingToPedestal, .loweringToPedestal: 0
            default: 1
            }
        }
        var lift: Double {
            switch self {
            // Lift and horizontal engagement are independent coordinates.
            case .travellingToRecord, .positionedAboveRecord: 1
            case .parked, .loweringToRecord, .tracking, .loweringToPedestal: 0
            default: 1
            }
        }
        var duration: TimeInterval {
            switch self {
            case .liftingPedestal, .liftingRecord, .loweringToRecord: MidnightTonearm.liftDuration
            case .travellingToRecord: MidnightTonearm.travelDuration
            case .travellingToPedestal: MidnightTonearm.parkDuration
            case .loweringToPedestal: MidnightTonearm.pedestalLowerDuration
            default: 0
            }
        }
    }

    private struct Input: Equatable {
        let itemID: String
        let playing: Bool
        let enabled: Bool
        let position: Int?
        let duration: Int?
        let sampledAt: TimeInterval?
    }

    var body: some View {
        TimelineView(TonearmTimelineSchedule(playing:playing || !motionComplete,active:enabled,
                                             reduceMotion:reduceMotion,sampledAt:sampledAt)) { timeline in
            let uptime = ProcessInfo.processInfo.systemUptime
            let pose = renderedPose(at:uptime)
            let engagement = enabled ? pose.y : 0
            GeometryReader { proxy in
                let geometry = TonearmGeometry(size: proxy.size, record: recordSurface)
                ElevatedTonearmDrawing(geometry: geometry, accent: accent, angle: Double(geometry.angle(progress:pose.x,engagement:engagement)),
                                       engagement: engagement,
                                       lift: enabled ? pose.z : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { synchronize(from:nil,to:input) }
        .onChange(of: input) { old, new in
            synchronize(from: old, to: new)
        }
        .onDisappear { sequenceTask?.cancel() }
        .onChange(of: idleDelay) { _, _ in
            if !playing && phase == .hoveringRecord { scheduleParking() }
        }
    }

    private var input: Input {
        Input(itemID:itemID, playing:playing, enabled:enabled, position:positionMilliseconds,
              duration:durationMilliseconds, sampledAt:sampledAt)
    }

    private func synchronize(from old: Input?, to new: Input) {
        if old == nil || old?.playing != new.playing || old?.itemID != new.itemID || isSeek(from:old,to:new) {
            eventPose = renderedPose(at:ProcessInfo.processInfo.systemUptime)
        }
        latestInput = new
        guard new.enabled else {
            sequenceTask?.cancel(); setPhase(.parked)
            onPlaybackMechanismChanged(new.playing)
            return
        }
        if old == nil {
            if restoresPlaybackState { restorePlaybackPose(new) }
            else if new.playing { beginPlayback(fromPedestal:true) }
            else if new.itemID == PlayingItem.idle.id { setPhase(.parked); onPlaybackMechanismChanged(false) }
            else { setPhase(.hoveringRecord); onPlaybackMechanismChanged(false); scheduleParking() }
            return
        }
        if old?.itemID != new.itemID {
            onPlaybackMechanismChanged(false)
            if new.itemID == PlayingItem.idle.id { stopAndPark() }
            else if new.playing { beginPlayback(fromPedestal:phase.engagement == 0,reposition:true) }
            else { moveRaisedToRecordThenPark() }
        } else if old?.playing != new.playing {
            if new.playing { beginPlayback(fromPedestal:phase == .parked || phase == .loweringToPedestal) }
            else { pauseAtCurrentGroove() }
        } else if isSeek(from:old, to:new) {
            // A fresh Spotify position can arrive during the initial cue.
            // The drawing already reads that new target; don't cancel a raised
            // transfer and start a second lift from the record side.
            if phase == .liftingPedestal || phase == .raisedPedestal ||
                phase == .travellingToRecord || phase == .positionedAboveRecord {
                retargetAfterTravel = phase == .travellingToRecord
                eventPose = nil
                return
            }
            if new.playing { seekWhilePlaying() }
            else { moveRaisedToRecordThenPark() }
        }
    }

    /// Recreated windows (wake, hot-plug or settings rebuild) join the current
    /// transport state without pretending a new record was just started.
    private func restorePlaybackPose(_ input: Input) {
        sequenceTask?.cancel()
        retargetAfterTravel = false
        eventPose = nil
        let restored = input.playing
            ? SIMD3<Double>(clockProgress(input), 1, 0)
            : SIMD3<Double>(clockProgress(input), 0, 0)
        fromPose = restored
        toPose = restored
        segmentStart = ProcessInfo.processInfo.systemUptime
        segmentDuration = 0
        motionComplete = true
        phase = input.playing ? .tracking : .parked
#if DEBUG
        TonearmAnimationDiagnostics.didEnterPhase?(String(describing:phase))
#endif
        onPlaybackMechanismChanged(input.playing)
    }

    private func isSeek(from old: Input?, to new: Input) -> Bool {
        guard let old, let oldPosition=old.position, let newPosition=new.position,
              old.duration == new.duration else { return false }
        let elapsed = old.playing ? max(0,(new.sampledAt ?? 0)-(old.sampledAt ?? 0))*1000 : 0
        let expected = Double(oldPosition)+elapsed
        // Player reads have sub-second timing jitter. Anything beyond that is
        // an authoritative transport relocation and receives a physical cue.
        return abs(Double(newPosition)-expected) > 350
    }

    private func beginPlayback(fromPedestal:Bool,reposition:Bool = false) {
        sequenceTask?.cancel()
        let reposition = reposition || latestInput.map {
            abs(clockProgress($0)-renderedPose(at:ProcessInfo.processInfo.systemUptime).x) > 0.003
        } == true
        onPlaybackMechanismChanged(false)
        sequenceTask = Task { @MainActor in
            do {
                if fromPedestal {
                    setPhase(.liftingPedestal)
                    try await wait(Self.liftDuration)
                    setPhase(.raisedPedestal)
                    await Task.yield()
                    try Task.checkCancellation()
                } else if phase == .tracking && !reposition {
                    onPlaybackMechanismChanged(true)
                    return
                } else if reposition && (phase == .tracking || phase == .loweringToRecord) {
                    setPhase(.liftingRecord)
                    try await wait(Self.liftDuration)
                }
                if fromPedestal || reposition || phase == .travellingToPedestal || phase == .loweringToPedestal {
                    setPhase(.travellingToRecord)
                    try await wait(Self.travelDuration)
                    setPhase(.positionedAboveRecord)
                    await Task.yield()
                    try Task.checkCancellation()
                }
                setPhase(.loweringToRecord)
                try await wait(Self.liftDuration)
                setPhase(.tracking)
                onPlaybackMechanismChanged(true)
            } catch { return }
        }
    }

    private func pauseAtCurrentGroove() {
        sequenceTask?.cancel()
        onPlaybackMechanismChanged(false)
        if phase.engagement == 0 {
            sequenceTask = Task { @MainActor in
                setPhase(.loweringToPedestal)
                do { try await wait(Self.pedestalLowerDuration); setPhase(.parked) }
                catch { return }
            }
            return
        }
        setPhase(.liftingRecord)
        sequenceTask = Task { @MainActor in
            do {
                try await wait(Self.liftDuration)
                setPhase(.hoveringRecord)
                try await wait(max(0,idleDelay-Self.liftDuration))
                try await parkRaisedArm()
            } catch { return }
        }
    }

    private func seekWhilePlaying() {
        sequenceTask?.cancel()
        setPhase(.liftingRecord)
        // The platter is already at speed; cueing the arm does not stop it.
        sequenceTask = Task { @MainActor in
            do {
                try await wait(Self.liftDuration)
                setPhase(.travellingToRecord)
                try await wait(Self.travelDuration)
                setPhase(.loweringToRecord)
                try await wait(Self.liftDuration)
                setPhase(.tracking)
                onPlaybackMechanismChanged(true)
            } catch { return }
        }
    }

    private func moveRaisedToRecordThenPark() {
        sequenceTask?.cancel()
        onPlaybackMechanismChanged(false)
        sequenceTask = Task { @MainActor in
            do {
                if phase == .parked || phase == .loweringToPedestal {
                    setPhase(.liftingPedestal)
                    try await wait(Self.liftDuration)
                } else if phase == .tracking || phase == .loweringToRecord {
                    setPhase(.liftingRecord)
                    try await wait(Self.liftDuration)
                }
                setPhase(.travellingToRecord)
                try await wait(Self.travelDuration)
                setPhase(.hoveringRecord)
                try await wait(idleDelay)
                try await parkRaisedArm()
            } catch { return }
        }
    }

    private func stopAndPark() {
        sequenceTask?.cancel()
        onPlaybackMechanismChanged(false)
        sequenceTask = Task { @MainActor in
            do {
                if phase == .tracking || phase == .loweringToRecord {
                    setPhase(.liftingRecord)
                    try await wait(Self.liftDuration)
                }
                try await parkRaisedArm()
            } catch { return }
        }
    }

    private func scheduleParking() {
        sequenceTask?.cancel()
        sequenceTask = Task { @MainActor in
            do {
                try await wait(idleDelay)
                try await parkRaisedArm()
            } catch { return }
        }
    }

    @MainActor private func parkRaisedArm() async throws {
        setPhase(.travellingToPedestal)
        try await wait(Self.parkDuration)
        setPhase(.loweringToPedestal)
        try await wait(Self.pedestalLowerDuration)
        setPhase(.parked)
    }

    private func setPhase(_ value:Phase) {
        let now = ProcessInfo.processInfo.systemUptime
        let start = eventPose ?? renderedPose(at:now)
        eventPose = nil
        var target = start
        target.y = value.engagement
        target.z = value.lift
        // Pedestal transfers retain the same checkpoints with a brisker sweep.
        let duration: TimeInterval = value == .travellingToRecord && start.y < 0.99
            ? 1.25 : (value == .liftingPedestal ? 0.45 : value.duration)
        if value == .travellingToRecord, let latestInput {
            target.x = clockProgress(latestInput, ahead: latestInput.playing ? duration + Self.liftDuration : 0)
        }
        fromPose = start
        toPose = target
        segmentStart = now
        segmentDuration = reduceMotion ? 0 : duration
        motionComplete = segmentDuration == 0
        phase = value
#if DEBUG
        TonearmAnimationDiagnostics.didEnterPhase?(String(describing:value))
#endif
    }

    private func wait(_ seconds: TimeInterval) async throws {
        try Task.checkCancellation()
        if reduceMotion && phase.duration > 0 { return }
        if phase.duration > 0 {
            while ProcessInfo.processInfo.systemUptime < segmentStart + segmentDuration {
                try await Task.sleep(for:.milliseconds(8))
            }
            try Task.checkCancellation()
            motionComplete = true
            if phase == .travellingToRecord && retargetAfterTravel {
                retargetAfterTravel = false
                setPhase(.travellingToRecord)
                try await wait(Self.travelDuration)
            }
            return
        }
        try await Task.sleep(for:.seconds(seconds), tolerance:.milliseconds(5))
        try Task.checkCancellation()
    }

    private func trackingProgress(atUptime uptime: TimeInterval, tick: Date) -> Double {
        _ = tick
        guard let positionMilliseconds, let durationMilliseconds, durationMilliseconds > 0 else { return progress }
        let elapsed = playing ? max(0,uptime-(sampledAt ?? uptime)) : 0
        return min(1,max(0,(Double(positionMilliseconds)+elapsed*1000)/Double(durationMilliseconds)))
    }

    private func clockProgress(_ sample: Input, ahead: TimeInterval = 0) -> Double {
        guard let position = sample.position, let duration = sample.duration, duration > 0 else { return progress }
        let elapsed = sample.playing ? max(0,ProcessInfo.processInfo.systemUptime-(sample.sampledAt ?? ProcessInfo.processInfo.systemUptime)) + ahead : 0
        return min(1,max(0,(Double(position)+elapsed*1000)/Double(duration)))
    }

    private func renderedPose(at uptime: TimeInterval) -> SIMD3<Double> {
        if phase == .tracking, let latestInput {
            return SIMD3(clockProgress(latestInput),1,0)
        }
        guard segmentDuration > 0 else { return toPose }
        let t = min(1,max(0,(uptime-segmentStart)/segmentDuration))
        let eased = t*t*(3-2*t)
        return fromPose + (toPose-fromPose)*eased
    }

}

/// Geometry is shared with the smoke check. The stylus follows the playable
/// annulus on a fixed-radius arc about the bearing while a record is engaged.
struct TonearmGeometry {
    let size: CGSize
    let record: CGRect
    var unit: CGFloat { size.height }
    var recordHeight: CGFloat { unit * 0.040 }
    var armHeight: CGFloat { recordHeight + unit * 0.100 }
    var headshellHeight: CGFloat { recordHeight + unit * 0.064 }
    var cueHeight: CGFloat { unit * 0.020 }
    var pivot: CGPoint { CGPoint(x: size.width * 0.703, y: unit * 0.230) }
    var aspect: CGFloat { record.height / record.width }
    // The straight terminal and cartridge point down-screen when parked.
    // The pedestal is now authored under that terminal, as requested.
    var pedestalAngle: CGFloat { parkedAngle }
    /// Centre X of the visible pedestal in the tonearm's local coordinate
    /// space. This is the value calibrated by the user via pedestalXOffset.
    var pedestalCenterX: CGFloat {
        let authored = ground(restLocal,angle:pedestalAngle)
        return authored.x + pedestalXOffset
    }
    /// Independent idle-animation target. It is sampled from the fixed
    /// pedestal centre, but the animation never feeds back into pedestal
    /// drawing or geometry.
    var tonearmParkCenterX: CGFloat { pedestalCenterX }
    var parkedAngle: CGFloat { .pi/2-atan2(shellDirection.y,shellDirection.x) }

    /// Cup midpoint is top + .001u; its upper surface is .003u above that.
    /// Subtract the tube radius (.006u). Top is .006u below the authored point.
    var cradleWireCenter: CGPoint {
        let point = elevated(restGround,height:restHeight)
        return CGPoint(x:point.x,y:point.y-unit*0.002)
    }
    var length: CGFloat {
        let radius = record.width * 0.5 * 0.88
        let first = CGPoint(x: record.midX + radius * cos(.pi * 0.20),
                            y: record.midY + recordHeight + radius * sin(.pi * 0.20) * aspect)
        return hypot(first.x-pivot.x, (first.y-pivot.y)/aspect)
    }
    var rest: CGPoint { ground(CGPoint(x:length,y:0), angle:parkedAngle) }

    func angle(progress: Double, engagement: Double) -> CGFloat {
        let target = contact(progress:progress)
        let playingAngle = atan2((target.y-pivot.y)/aspect,target.x-pivot.x)
        return parkedAngle + (playingAngle-parkedAngle)*min(max(engagement,0),1)
    }

    func ground(_ local: CGPoint, angle: CGFloat) -> CGPoint {
        CGPoint(x:pivot.x+local.x*cos(angle)-local.y*sin(angle),
                y:pivot.y+(local.x*sin(angle)+local.y*cos(angle))*aspect)
    }

    func height(at t: CGFloat, lift: Double) -> CGFloat {
        // A gradual descent preserves the single convex silhouette. A late
        // smoothstep drop introduced a second visible bend near the headshell.
        return armHeight+(headshellHeight-armHeight)*t+cueHeight*lift*t
    }

    // One rigid, convex bow follows the annotated silhouette. All points are
    // authored in the deck plane, then rotated about the same fixed bearing.
    // In particular, idle and playback never interpolate separate curve shapes.
    // A 40° fitting keeps the upright parked assembly clear of the display.
    var shellDirection: CGPoint { CGPoint(x: cos(CGFloat.pi * 40/180), y: sin(CGFloat.pi * 40/180)) }
    var shellLocal: CGPoint {
        CGPoint(x: length, y: 0)
    }

    // Longer handles distribute the turn across the broad middle. Parameter
    // spans match the adjoining line derivatives, including elevation.
    var bowStartHandle: CGFloat { unit*0.260 }
    var bowEndHandle: CGFloat { length*0.38 }
    var bowSpan: CGFloat { 1/(1+unit*0.060/(3*bowStartHandle)+unit*0.030/(3*bowEndHandle)) }
    var tubeLeadFraction: CGFloat { bowSpan*unit*0.060/(3*bowStartHandle) }
    var tubeTailFraction: CGFloat { bowSpan*unit*0.030/(3*bowEndHandle) }

    func tubePoint(at t: CGFloat) -> CGPoint {
        let end = CGPoint(x: length-unit*0.056*shellDirection.x,
                          y: -unit*0.056*shellDirection.y)
        let direction = CGPoint(x: 0.22/hypot(0.22,0.38), y: -0.38/hypot(0.22,0.38))
        let lead = unit*0.060
        let join = CGPoint(x: lead*direction.x, y: lead*direction.y)
        if t <= tubeLeadFraction { return CGPoint(x: join.x*t/tubeLeadFraction, y: join.y*t/tubeLeadFraction) }
        // A short straight fitting leads into the cartridge. Author it once
        // in the rigid arm's local coordinates, so it cannot flex during swing.
        let tailLength = unit*0.030
        let tail = CGPoint(x:end.x-tailLength*shellDirection.x,
                           y:end.y-tailLength*shellDirection.y)
        if t >= 1-tubeTailFraction {
            let q = (t-(1-tubeTailFraction))/tubeTailFraction
            return CGPoint(x:tail.x+(end.x-tail.x)*q,y:tail.y+(end.y-tail.y)*q)
        }
        // Match the line's derivative at the join, including its elevation.
        // The collar and the tube now remain coaxial until clear of the mount.
        return cubic(join,
                     CGPoint(x: join.x+direction.x*bowStartHandle, y: join.y+direction.y*bowStartHandle),
                     CGPoint(x: tail.x-bowEndHandle*shellDirection.x,
                             y: tail.y-bowEndHandle*shellDirection.y),
                     tail, t: (t-tubeLeadFraction)/bowSpan)
    }

    // Support the terminal, immediately before the cartridge connector.
    var restLocal: CGPoint { tubePoint(at:1) }
    /// Manual calibration point for the complete visible rest/cradle group.
    /// Increase to move it right; decrease (including negative values) to move
    /// it left. The arm's parked target follows this same centre X.
    var pedestalXOffset: CGFloat { unit * 0.0 }
    var restGround: CGPoint {
        let authored = ground(restLocal,angle:pedestalAngle)
        return CGPoint(x:authored.x+pedestalXOffset,y:authored.y+unit*0.002)
    }
    var restHeight: CGFloat { height(at:1,lift:0) }

    private func cubic(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint,_ d:CGPoint,t:CGFloat)->CGPoint {
        let s=1-t
        return CGPoint(x:s*s*s*a.x+3*s*s*t*b.x+3*s*t*t*c.x+t*t*t*d.x,
                       y:s*s*s*a.y+3*s*s*t*b.y+3*s*t*t*c.y+t*t*t*d.y)
    }

    func contact(progress: Double) -> CGPoint {
        // Solve in the record plane, undoing its authored elliptical foreshortening.
        let aspect = record.height / record.width
        let center = CGPoint(x: record.midX, y: (record.midY + recordHeight) / aspect)
        let bearing = CGPoint(x: pivot.x, y: pivot.y / aspect)
        let outerRadius = record.width * 0.5 * 0.88
        let first = CGPoint(x: center.x + outerRadius * cos(.pi * 0.20),
                            y: center.y + outerRadius * sin(.pi * 0.20))
        let length = hypot(first.x - bearing.x, first.y - bearing.y)
        let radius = record.width * 0.5 * (0.88 - 0.42 * min(max(progress, 0), 1))
        let dx = bearing.x - center.x, dy = bearing.y - center.y
        let distance = hypot(dx, dy)
        let along = (radius * radius - length * length + distance * distance) / (2 * distance)
        let across = sqrt(max(0, radius * radius - along * along))
        return CGPoint(x: center.x + along * dx / distance - across * dy / distance,
                       y: (center.y + along * dy / distance + across * dx / distance) * aspect)
    }

    func elevated(_ point: CGPoint, height: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: point.y - height)
    }

    /// The same light direction is used on each receiver. Crossing the platter
    /// changes both shadow position and penumbra because that surface is higher.
    func shadow(_ point: CGPoint, height: CGFloat, receiver: CGFloat) -> CGPoint {
        let clearance = max(0, height - receiver)
        return CGPoint(x: point.x + clearance * 0.38,
                       y: point.y - receiver + clearance * 0.24)
    }
}

private struct ElevatedTonearmDrawing: View, Animatable {
    @Environment(\.turntableMaterials) private var materials
    let geometry: TonearmGeometry
    let accent: Color
    var angle: Double
    var engagement: Double
    var lift: Double

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(angle, AnimatablePair(engagement, lift)) }
        set {
            angle = newValue.first
            engagement = newValue.second.first
            lift = newValue.second.second
        }
    }

    var body: some View {
        Canvas { context, _ in
#if DEBUG
            TonearmAnimationDiagnostics.didDraw?(self.angle)
#endif
            let g = geometry, u = g.unit
            let angle = CGFloat(self.angle)
            let pivot = g.elevated(g.pivot, height: g.armHeight)
            let height = g.headshellHeight + g.cueHeight * lift
            let shellGround = g.ground(g.shellLocal,angle:angle)
            let shell = g.elevated(shellGround,height:height)
#if DEBUG
            TonearmAnimationDiagnostics.didDrawPose?(engagement, lift, shell.y)
#endif
            let contact = shellGround
            let tubePoints = (0...80).map { index -> CGPoint in
                let t=CGFloat(index)/80
                return g.elevated(g.ground(g.tubePoint(at:t),angle:angle),
                                  height:g.height(at:t,lift:lift))
            }
            let tubeEnd = tubePoints[80]
#if DEBUG
            TonearmAnimationDiagnostics.didDrawTube?(tubePoints,g.cradleWireCenter,engagement,lift)
            TonearmAnimationDiagnostics.didDrawBearingGap?(hypot(tubePoints[0].x-pivot.x,tubePoints[0].y-pivot.y))
#endif
            let axis = direction(tubeEnd,shell)
            let headAngle=atan2(axis.dy / g.aspect,axis.dx)
            let headForeshortening=hypot(cos(headAngle),g.aspect*sin(headAngle))
            let rearAxis = direction(tubePoints[0],tubePoints[1])
            let rear = shifted(pivot, rearAxis, -u * 0.063)

            // 1. Receiver shadows. Clip the two shadow passes to the actual
            // record ellipse, so the tube shadow steps up onto the vinyl.
            for receiver in [CGFloat.zero, g.recordHeight] {
                var shadow = context
                shadow.clip(to: Path(ellipseIn: g.record), options: receiver == 0 ? .inverse : [])
                shadow.addFilter(.blur(radius: receiver == 0 ? u * 0.009 : u * 0.0055))
                let shadowPoints = (0...80).map { index -> CGPoint in
                    let t=CGFloat(index)/80
                    let elevation=g.height(at:t,lift:lift)
                    let point=tubePoints[index]
                    return g.shadow(CGPoint(x:point.x,y:point.y+elevation),height:elevation,receiver:receiver)
                }
                var shadowPath=Path();shadowPath.addLines(shadowPoints)
                shadow.stroke(shadowPath,with:.color(.black.opacity(0.50)),style:StrokeStyle(lineWidth:u*0.012,lineCap:.round,lineJoin:.round))
                let shadowShell = g.shadow(shellGround,height:height,receiver:receiver)
                shadow.fill(box(center: shadowShell, axis: axis, length: u * 0.069, width: u * 0.026), with: .color(.black.opacity(0.60)))
                let rearGround = CGPoint(x: rear.x, y: rear.y + g.armHeight)
                let rearShadow = g.shadow(rearGround, height: g.armHeight, receiver: receiver)
                line(&shadow, shifted(rearShadow, rearAxis, -u * 0.034), shifted(rearShadow, rearAxis, u * 0.034), width: u * 0.055, color: .black.opacity(0.50))
            }

            // 2. Mount and a visible vertical pedestal; neither can occlude
            // the tube that passes above the top bearing.
            pedestal(&context, base: g.pivot, top: pivot, unit: u, accent: accent)
            armRest(&context, unit: u)

            // 3. Rear shaft and cylindrical counterweight above the mount.
            tube(&context, from: rear, to: pivot, diameter: u * 0.013)
            tube(&context, from: shifted(rear, rearAxis, -u * 0.032),
                 to: shifted(rear, rearAxis, u * 0.030), diameter: u * 0.051, cap:.butt)
            let frontCap=ellipse(center:shifted(rear,rearAxis,u*0.030),width:u*0.014,height:u*0.051,angle:atan2(rearAxis.dy,rearAxis.dx))
            context.fill(frontCap,with:.color(materials.tonearm.shade(TonearmMetalLighting.capBrightness(axis:rearAxis))))
            context.stroke(frontCap,with:.color(.white.opacity(0.12)),lineWidth:u*0.001)
            let endCap = shifted(rear, rearAxis, -u * 0.032)
            let cap = ellipse(center: endCap, width: u * 0.014, height: u * 0.051, angle: atan2(rearAxis.dy, rearAxis.dx))
            let capNormal = CGVector(dx:-rearAxis.dy,dy:rearAxis.dx)
            let capLight = TonearmMetalLighting.capBrightness(axis:CGVector(dx:-rearAxis.dx,dy:-rearAxis.dy))
            context.fill(cap, with: .linearGradient(Gradient(colors: [materials.tonearm.shade(capLight+0.08),materials.tonearm.shade(capLight-0.04)]), startPoint:shifted(endCap,capNormal,-u*0.025), endPoint:shifted(endCap,capNormal,u*0.025)))
            context.stroke(cap, with: .color(.black.opacity(0.60)), lineWidth: u * 0.001)

            // 4. Continuous elevated tube, with small machined connections.
            curvedTube(&context,points:tubePoints,diameter:u*0.012)
            // The shell is drawn over this connector: overlap its interior
            // at every orientation rather than stopping at a fixed distance.
            tube(&context, from:tubeEnd, to:shell, diameter:u*0.012)
            tube(&context, from: shifted(pivot, rearAxis, u * 0.018), to: shifted(pivot, rearAxis, u * 0.038), diameter: u * 0.019)
            tube(&context, from: shifted(tubeEnd, axis, -u * 0.007), to: shifted(tubeEnd, axis, u * 0.008), diameter: u * 0.014)
            bearing(&context, center: pivot, unit: u)

            // 5. A downward stylus beneath the cartridge. Draw it first so
            // its attachment is hidden by the body, never painted on its face.
            let stylusHeight = g.recordHeight + g.cueHeight * lift
            let contactHeight = g.elevated(contact, height: stylusHeight)
            var contactShadow = context
            contactShadow.addFilter(.blur(radius: u * (0.0008 + 0.002 * lift)))
            let contactOnRecord = g.elevated(contact, height: g.recordHeight)
            contactShadow.fill(Path(ellipseIn: CGRect(x: contactOnRecord.x-u*0.003, y:contactOnRecord.y-u*0.001, width:u*0.006,height:u*0.0025)), with: .color(.black.opacity(0.85 * engagement * (1-lift))))
            let stylus = CGPoint(x:shell.x, y:contactHeight.y)
            let cartridgeTop = CGPoint(x: shell.x, y: shell.y + u*0.007)
            let cartridgeBottom = CGPoint(x: cartridgeTop.x, y: cartridgeTop.y+u*0.024)
            let cartridge = extrusion(center:cartridgeTop,axis:axis,length:u*0.036*headForeshortening,width:u*0.023,depth:u*0.024)
            // Elevation is vertical in the scene, independent of arm rotation.
            let cantileverRoot = cartridgeBottom
            let diamond = CGPoint(x:stylus.x,y:stylus.y-u*0.003)
            line(&context,cantileverRoot,diamond,width:u*0.0025,color:materials.tonearm.shade(0.12))
            line(&context,CGPoint(x:cantileverRoot.x-u*0.0005,y:cantileverRoot.y-u*0.0005),diamond,width:u*0.0012,color:materials.tonearm.shade(0.56))
            context.fill(polygon([CGPoint(x:diamond.x-u*0.0009,y:diamond.y),
                                  CGPoint(x:diamond.x+u*0.0009,y:diamond.y),stylus]),
                         with:.color(materials.tonearm.shade(0.75)))
            context.fill(cartridge, with: .linearGradient(Gradient(colors:materials.tonearm.cartridge), startPoint:cartridgeTop, endPoint:CGPoint(x:cartridgeBottom.x,y:cartridgeBottom.y+u*0.011)))
            context.stroke(cartridge, with:.color(.black.opacity(0.8)),lineWidth:u*0.0012)

            // Extruded side faces connect two equal footprints vertically.
            let top = box(center:shell,axis:axis,length:u*0.071*headForeshortening,width:u*0.027)
            let bottom = top.applying(CGAffineTransform(translationX:0,y:u*0.009))
            context.fill(bottom,with:.color(materials.tonearm.cartridgeBottom))
            let normal = CGVector(dx:-axis.dy,dy:axis.dx)
            let edgeA = shifted(shifted(shell,axis,-u*0.0355*headForeshortening),normal,-u*0.0135)
            let edgeB = shifted(shifted(shell,axis,u*0.0355*headForeshortening),normal,-u*0.0135)
            context.fill(polygon([edgeA,edgeB,CGPoint(x:edgeB.x,y:edgeB.y+u*0.009),CGPoint(x:edgeA.x,y:edgeA.y+u*0.009)]),with:.color(materials.tonearm.headshellEdge))
            context.fill(top,with:.linearGradient(Gradient(colors:materials.tonearm.headshell),startPoint:CGPoint(x:shell.x-u*0.024,y:shell.y-u*0.018),endPoint:CGPoint(x:shell.x+u*0.024,y:shell.y+u*0.018)))
            context.stroke(top,with:.color(.white.opacity(0.10)),lineWidth:u*0.0008)
            for offset in [-0.016,0.013] {
                let screw = shifted(shell,axis,u*offset*headForeshortening)
                context.fill(Path(ellipseIn:CGRect(x:screw.x-u*0.0022,y:screw.y-u*0.0018,width:u*0.0044,height:u*0.0036)),with:.color(materials.tonearm.shade(0.41)))
                line(&context,CGPoint(x:screw.x-u*0.0012,y:screw.y),CGPoint(x:screw.x+u*0.0012,y:screw.y),width:u*0.0007,color:.black.opacity(0.8))
            }
        }
        .turntableFinish(materials.tonearm.finish)
    }

    private func pedestal(_ context: inout GraphicsContext, base: CGPoint, top: CGPoint, unit u: CGFloat, accent: Color) {
        var shadow=context
        shadow.addFilter(.blur(radius:u*0.004))
        shadow.fill(Path(ellipseIn:CGRect(x:base.x-u*0.074,y:base.y-u*0.022,width:u*0.154,height:u*0.065)),with:.color(.black.opacity(0.80)))
        let lowerRing = CGPoint(x:base.x,y:base.y-u*0.010)
        let upperRing = CGPoint(x:base.x,y:base.y-u*0.026)
        drum(&context,center:lowerRing,width:u*0.153,depth:u*0.067,thickness:u*0.014,light:0.23)
        drum(&context,center:upperRing,width:u*0.110,depth:u*0.048,thickness:u*0.018,light:0.29)
        ledRing(&context,center:lowerRing,width:u*0.153,depth:u*0.067,accent:accent,unit:u,strength:1)
        ledRing(&context,center:upperRing,width:u*0.110,depth:u*0.048,accent:accent,unit:u,strength:1)
        // Narrow bearing tower makes the clearance above the base legible.
        let tower = CGPoint(x:top.x,y:top.y+u*0.009)
        drum(&context,center:tower,width:u*0.078,depth:u*0.038,thickness:base.y-top.y-u*0.035,light:0.29)
        // The wider shoulder below the bearing gets its own album-colour edge,
        // slightly stronger than the finer upper recess ring.
        ledRing(&context,center:tower,width:u*0.078,depth:u*0.038,accent:accent,unit:u,strength:0.82)
        let recess=Path(ellipseIn:CGRect(x:top.x-u*0.030,y:top.y-u*0.010,width:u*0.060,height:u*0.027))
        context.fill(recess,with:.color(materials.tonearm.shade(0.018)))
        context.stroke(recess,with:.linearGradient(Gradient(colors:[.black,.white.opacity(0.13)]),startPoint:CGPoint(x:top.x,y:top.y-u*0.014),endPoint:CGPoint(x:top.x,y:top.y+u*0.016)),lineWidth:u*0.002)
        // A finer, lower-intensity LED edge marks the bearing recess around
        // the ball without competing with the two larger base rings.
        ledRing(&context,center:CGPoint(x:top.x,y:top.y),width:u*0.060,depth:u*0.027,accent:accent,unit:u,strength:0.62)
    }

    private func ledRing(_ context: inout GraphicsContext, center: CGPoint, width: CGFloat, depth: CGFloat, accent: Color, unit u: CGFloat, strength: CGFloat) {
        let ring=Path(ellipseIn:CGRect(x:center.x-width/2,y:center.y-depth/2,width:width,height:depth))
        var bloom=context
        bloom.addFilter(.blur(radius:u*0.004))
        bloom.stroke(ring,with:.color(accent.opacity(0.55*strength)),style:StrokeStyle(lineWidth:u*0.006,lineCap:.round))
        context.stroke(ring,with:.color(accent.opacity(0.72*strength)),style:StrokeStyle(lineWidth:u*0.0014,lineCap:.round))
    }

    private func bearing(_ context: inout GraphicsContext, center p: CGPoint, unit u: CGFloat) {
        // The tube enters the raised bearing, not beneath the mounting plate.
        let cap=Path(ellipseIn:CGRect(x:p.x-u*0.018,y:p.y-u*0.014,width:u*0.036,height:u*0.029))
        context.fill(cap,with:.radialGradient(Gradient(stops:[.init(color:materials.tonearm.shade(0.63),location:0),.init(color:materials.tonearm.shade(0.30),location:0.27),.init(color:materials.tonearm.shade(0.075),location:0.80),.init(color:materials.tonearm.shade(0.18),location:1)]),center:CGPoint(x:p.x-u*0.007,y:p.y-u*0.008),startRadius:0,endRadius:u*0.030))
        context.stroke(cap,with:.color(.black.opacity(0.50)),lineWidth:u*0.001)
    }

    private func armRest(_ context: inout GraphicsContext, unit u: CGFloat) {
        let base=geometry.restGround
        let tubeCenter=geometry.elevated(base,height:geometry.restHeight)
        let top=CGPoint(x:tubeCenter.x,y:tubeCenter.y+u*0.006)
        var shadow=context
        shadow.addFilter(.blur(radius:u*0.003))
        line(&shadow,base,CGPoint(x:base.x+(base.y-top.y)*0.38,y:base.y+(base.y-top.y)*0.24),width:u*0.007,color:.black.opacity(0.45))
        drum(&context,center:base,width:u*0.032,depth:u*0.022,thickness:u*0.007,light:0.17)
        line(&context,base,top,width:u*0.012,color:materials.tonearm.shade(0.065))
        line(&context,CGPoint(x:base.x-u*0.004,y:base.y),CGPoint(x:top.x-u*0.004,y:top.y),width:u*0.002,color:materials.tonearm.shade(0.23))
        var cradle=Path()
        cradle.move(to:CGPoint(x:top.x-u*0.014,y:top.y-u*0.017))
        cradle.addLine(to:CGPoint(x:top.x-u*0.012,y:top.y-u*0.004))
        cradle.addQuadCurve(to:CGPoint(x:top.x+u*0.012,y:top.y-u*0.004),control:CGPoint(x:top.x,y:top.y+u*0.006))
        cradle.addLine(to:CGPoint(x:top.x+u*0.014,y:top.y-u*0.017))
        context.stroke(cradle,with:.color(materials.tonearm.shade(0.11)),style:StrokeStyle(lineWidth:u*0.006,lineCap:.round))
        context.stroke(cradle,with:.color(.white.opacity(0.16)),style:StrokeStyle(lineWidth:u*0.001,lineCap:.round))
    }

    private func curvedTube(_ context: inout GraphicsContext, points: [CGPoint], diameter: CGFloat) {
        let radius=diameter/2
        let normals=points.indices.map { i -> CGVector in
            let tangent=direction(points[max(0,i-1)],points[min(points.count-1,i+1)])
            return CGVector(dx:-tangent.dy,dy:tangent.dx)
        }
        let upper=zip(points,normals).map { shifted($0.0,$0.1,radius) }
        let lower=zip(points,normals).map { shifted($0.0,$0.1,-radius) }
        let outline=polygon(upper+lower.reversed())
        var tubeContext=context
        tubeContext.clip(to:outline)
        // Each connected ribbon segment shades across its own tangent normal,
        // so specular reflections turn with the curve instead of cutting across it.
        for i in 0..<(points.count-1) {
            let normal=normals[i]
            let facing = Double(-(normal.dx+normal.dy)/sqrt(2))
            // A continuous cylindrical normal avoids a highlight flipping sides
            // abruptly as a curved span passes through the light direction.
            let material=Gradient(stops:(0...12).map { band in
                let across=Double(band)/6-1
                let roundness=sqrt(max(0,1-across*across))
                let diffuse=max(0,0.65*roundness+0.30*across*facing)
                let specular=pow(max(0,0.92*roundness+0.39*across*facing),22)
                let value=min(0.74,0.055+0.22*diffuse+0.48*specular)
                return Gradient.Stop(color:materials.tonearm.shade(value),location:CGFloat(band)/12)
            })
            let middle=CGPoint(x:(points[i].x+points[i+1].x)/2,y:(points[i].y+points[i+1].y)/2)
            let tangent=direction(points[i],points[i+1])
            let patch=polygon([shifted(upper[i],tangent,-0.5),shifted(upper[i+1],tangent,0.5),
                               shifted(lower[i+1],tangent,0.5),shifted(lower[i],tangent,-0.5)])
            tubeContext.fill(patch,with:.linearGradient(material,startPoint:shifted(middle,normal,-radius),endPoint:shifted(middle,normal,radius)),style:FillStyle(antialiased:false))
        }
        tubeContext.fill(outline,with:.linearGradient(Gradient(colors:[.black.opacity(0.18),.clear,.black.opacity(0.10)]),startPoint:points[0],endPoint:points[points.count-1]))
    }

    private func extrusion(center:CGPoint,axis:CGVector,length:CGFloat,width:CGFloat,depth:CGFloat)->Path {
        let normal=CGVector(dx:-axis.dy,dy:axis.dx)
        let corners=[shifted(shifted(center,axis,-length/2),normal,-width/2),
                     shifted(shifted(center,axis,length/2),normal,-width/2),
                     shifted(shifted(center,axis,length/2),normal,width/2),
                     shifted(shifted(center,axis,-length/2),normal,width/2)]
        // One convex silhouette avoids winding cancellation between overlapping
        // front/back faces, which otherwise makes a solid cartridge look hollow.
        let points=(corners+corners.map { CGPoint(x:$0.x,y:$0.y+depth) })
            .sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        func cross(_ a:CGPoint,_ b:CGPoint,_ c:CGPoint)->CGFloat {
            (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)
        }
        var lower=[CGPoint](),upper=[CGPoint]()
        for point in points {
            while lower.count >= 2 && cross(lower[lower.count-2],lower[lower.count-1],point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        for point in points.reversed() {
            while upper.count >= 2 && cross(upper[upper.count-2],upper[upper.count-1],point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        return polygon(Array(lower.dropLast())+Array(upper.dropLast()))
    }

    private func drum(_ context: inout GraphicsContext, center: CGPoint, width: CGFloat, depth: CGFloat, thickness: CGFloat, light: Double) {
        let rect=CGRect(x:center.x-width/2,y:center.y-depth/2,width:width,height:depth)
        var wall=Path()
        wall.addRect(CGRect(x:rect.minX,y:center.y,width:width,height:thickness))
        wall.addEllipse(in:rect.offsetBy(dx:0,dy:thickness))
        context.fill(wall,with:.linearGradient(Gradient(colors:[materials.tonearm.shade(light*0.55),materials.tonearm.shade(0.045),materials.tonearm.shade(0.018)]),startPoint:CGPoint(x:rect.minX,y:center.y),endPoint:CGPoint(x:rect.maxX,y:center.y+thickness)))
        context.fill(Path(ellipseIn:rect),with:.linearGradient(Gradient(colors:[materials.tonearm.shade(light),materials.tonearm.shade(0.085),materials.tonearm.shade(0.035)]),startPoint:CGPoint(x:rect.minX,y:rect.minY),endPoint:CGPoint(x:rect.maxX,y:rect.maxY)))
        context.stroke(Path(ellipseIn:rect),with:.linearGradient(Gradient(colors:[.white.opacity(0.21),.black.opacity(0.70)]),startPoint:CGPoint(x:rect.minX,y:rect.minY),endPoint:CGPoint(x:rect.maxX,y:rect.maxY)),lineWidth:geometry.unit*0.0011)
    }

    private func tube(_ context: inout GraphicsContext, from a: CGPoint, to b: CGPoint, diameter: CGFloat, cap: CGLineCap = .round) {
        let axis=direction(a,b)
        let n=CGVector(dx:-axis.dy,dy:axis.dx)
        let radius=diameter/2
        var path=Path(); path.move(to:a); path.addLine(to:b)
        let section=Gradient(stops:(0...24).map { band in
            .init(color:materials.tonearm.shade(TonearmMetalLighting.brightness(across:Double(band)/12-1,normal:n)),location:CGFloat(band)/24)
        })
        context.stroke(path,with:.linearGradient(section,startPoint:shifted(a,n,-radius),endPoint:shifted(a,n,radius)),style:StrokeStyle(lineWidth:diameter,lineCap:cap))
        context.stroke(path,with:.linearGradient(Gradient(colors:[.black.opacity(0.20),.clear,.black.opacity(0.10),.clear]),startPoint:a,endPoint:b),style:StrokeStyle(lineWidth:diameter,lineCap:cap))
    }

    private func direction(_ a: CGPoint,_ b: CGPoint) -> CGVector {
        let length=max(1,hypot(b.x-a.x,b.y-a.y))
        return CGVector(dx:(b.x-a.x)/length,dy:(b.y-a.y)/length)
    }
    private func shifted(_ p: CGPoint,_ axis: CGVector,_ distance: CGFloat) -> CGPoint {
        CGPoint(x:p.x+axis.dx*distance,y:p.y+axis.dy*distance)
    }
    private func line(_ context: inout GraphicsContext,_ a: CGPoint,_ b: CGPoint,width: CGFloat,color: Color) {
        var p=Path();p.move(to:a);p.addLine(to:b)
        context.stroke(p,with:.color(color),style:StrokeStyle(lineWidth:width,lineCap:.round))
    }
    private func polygon(_ points: [CGPoint]) -> Path {
        Path { p in p.addLines(points);p.closeSubpath() }
    }
    private func box(center: CGPoint,axis: CGVector,length: CGFloat,width: CGFloat) -> Path {
        let n=CGVector(dx:-axis.dy,dy:axis.dx)
        return polygon([shifted(shifted(center,axis,-length/2),n,-width/2),shifted(shifted(center,axis,length/2),n,-width/2),shifted(shifted(center,axis,length/2),n,width/2),shifted(shifted(center,axis,-length/2),n,width/2)])
    }
    private func ellipse(center: CGPoint,width: CGFloat,height: CGFloat,angle: CGFloat) -> Path {
        Path(ellipseIn:CGRect(x:-width/2,y:-height/2,width:width,height:height))
            .applying(CGAffineTransform(rotationAngle:angle).concatenating(CGAffineTransform(translationX:center.x,y:center.y)))
    }
}

/// Continuous cylindrical lighting under the scene's fixed upper-left light.
/// A signed dot product moves the highlight smoothly across the material;
/// there is no hemisphere switch as the rigid assembly rotates.
enum TonearmMetalLighting {
    static func brightness(across: Double, normal: CGVector) -> Double {
        let facing = Double(-(normal.dx+normal.dy)/sqrt(2))
        let roundness = sqrt(max(0,1-across*across))
        let diffuse = max(0,0.65*roundness+0.30*across*facing)
        let specular = pow(max(0,0.92*roundness+0.39*across*facing),22)
        return min(0.74,0.055+0.22*diffuse+0.48*specular)
    }

    static func capBrightness(axis: CGVector) -> Double {
        let facing = Double(-(axis.dx+axis.dy)/sqrt(2))
        return 0.10+0.24*max(0,facing)
    }
}
