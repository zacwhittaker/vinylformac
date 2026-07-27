import SwiftUI

/// Legacy canvas renderer. The active wallpaper uses SpinningArtwork's native
/// bitmap layer. Keep this content's identity stable when playback changes.
struct SmoothRecordRotation<Content: View>: View {
    let startingAngle: Double
    let isPlaying: Bool
    @ViewBuilder let content: () -> Content
    @State private var angle = 0.0
    @State private var baseAngle = 0.0
    @State private var startedAt: TimeInterval?
    var body: some View {
        content().rotationEffect(.degrees(angle))
            .onAppear {
                baseAngle = startingAngle
                updatePlayback()
            }
            .onChange(of: isPlaying) { _, _ in updatePlayback() }
    }
    private func updatePlayback() {
        if let startedAt {
            baseAngle += max(0, ProcessInfo.processInfo.systemUptime - startedAt) * 30
        }
        startedAt = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { angle = baseAngle }
        if isPlaying {
            startedAt = ProcessInfo.processInfo.systemUptime
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                angle = baseAngle + 360
            }
        }
    }
}
