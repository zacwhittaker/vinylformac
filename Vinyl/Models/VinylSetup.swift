import Foundation

struct VinylSetup: Identifiable, Hashable {
    enum ID: String, CaseIterable {
        case albumCanvas
        case classicDeck
        case floatingVinyl
        case listeningRoom
        case sideA
        case afterDark
    }

    enum Availability: Hashable {
        case available
        case comingSoon
    }

    let id: ID
    let name: String
    let description: String
    let availability: Availability

    var isAvailable: Bool {
        availability == .available
    }

    static let catalogue: [VinylSetup] = [
        VinylSetup(
            id: .albumCanvas,
            name: "Turntable",
            description: "",
            availability: .available
        ),
        VinylSetup(
            id: .classicDeck,
            name: "",
            description: "",
            availability: .comingSoon
        ),
        VinylSetup(
            id: .floatingVinyl,
            name: "",
            description: "",
            availability: .comingSoon
        )
    ]
}
