import AppKit
import CoreGraphics

struct DisplayInfo: Identifiable, Equatable {
    let id: String
    let displayID: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let pixelSize: CGSize
    let scale: CGFloat

    var isPortrait: Bool { frame.height > frame.width }
    var aspectRatio: Double { frame.width / max(frame.height, 1) }
    var orientationName: String { isPortrait ? "Portrait" : "Landscape" }
    var resolution: String { "\(Int(pixelSize.width)) × \(Int(pixelSize.height))" }
}

@MainActor
final class DisplayManager: ObservableObject {
    @Published private(set) var displays: [DisplayInfo] = []
    @Published var identificationVisible = false
    private var observer: NSObjectProtocol?
    private var identifyTask: Task<Void, Never>?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } }
    }

    func refresh() {
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = CGDirectDisplayID(number.uint32Value)
            let width = CGDisplayPixelsWide(displayID)
            let height = CGDisplayPixelsHigh(displayID)
            let name = screen.localizedName.isEmpty ? "Display \(displayID)" : screen.localizedName
            return DisplayInfo(
                id: String(displayID), displayID: displayID, name: name, frame: screen.frame,
                pixelSize: CGSize(width: width, height: height), scale: screen.backingScaleFactor
            )
        }
    }

    func identifyDisplays() {
        identifyTask?.cancel()
        identificationVisible = true
        identifyTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            identificationVisible = false
        }
    }
}
