import SwiftUI

struct ArtworkBackdrop: View {
    let item: PlayingItem?
    var showsMetadata = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                baseGradient

                if let artworkURL = item?.artworkURL {
                    AsyncImage(url: artworkURL, transaction: Transaction(animation: .easeInOut(duration: 0.5))) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .transition(.opacity)
                        case .failure:
                            baseGradient
                        case .empty:
                            baseGradient
                                .overlay {
                                    ProgressView()
                                        .controlSize(.large)
                                        .tint(.white)
                                }
                        @unknown default:
                            baseGradient
                        }
                    }
                }

                LinearGradient(
                    colors: [
                        .black.opacity(0.04),
                        .black.opacity(0.14),
                        .black.opacity(0.52)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if showsMetadata, let item {
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title)
                                    .font(.system(size: 17, weight: .semibold))
                                Text(item.artist)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                            Spacer()
                            Label("Artwork supplied by Spotify", systemImage: "music.note")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .foregroundStyle(.white)
                        .padding(28)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private var baseGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.17, blue: 0.22),
                Color(red: 0.09, green: 0.08, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
