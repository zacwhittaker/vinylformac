import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            ArtworkBackdrop(item: model.currentItem)
                .ignoresSafeArea()

            Color.black.opacity(model.currentItem == nil ? 0.06 : 0.22)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 30)
                mainCard
                Spacer(minLength: 30)
                footer
            }
            .padding(34)
        }
        .frame(minWidth: 760, minHeight: 610)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 11) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Vinyl")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text("Your music, across the desktop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            statusPill
        }
    }

    private var statusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(model.statusMessage)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var mainCard: some View {
        HStack(spacing: 28) {
            artworkCard
            controlPanel
        }
        .padding(28)
        .frame(maxWidth: 860)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 40, y: 18)
    }

    private var artworkCard: some View {
        Group {
            if let url = model.currentItem?.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        artworkPlaceholder.overlay { ProgressView() }
                    case .failure:
                        artworkPlaceholder
                    @unknown default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 290, height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 22, y: 14)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.56, blue: 0.39),
                    Color(red: 0.42, green: 0.16, blue: 0.31)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "record.circle")
                .font(.system(size: 112, weight: .thin))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.isConnected {
                connectedPanel
            } else {
                connectionPanel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Connect Spotify")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("Vinyl only asks to read what is currently playing. Your token stays in Keychain.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Spotify Client ID")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Paste your Client ID", text: $model.clientID)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.connectionState == .connecting)
                Text("Dashboard redirect: \(SpotifyConfiguration.callbackURLString)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }

            Button {
                model.connect()
            } label: {
                HStack {
                    if model.connectionState == .connecting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(model.connectionState == .connecting ? "Connecting…" : "Connect Spotify")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canConnect)

            if let errorMessage = model.errorMessage {
                errorView(errorMessage)
            }
        }
    }

    private var connectedPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.currentItem?.title ?? "Waiting for music")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .lineLimit(2)
                Text(model.currentItem?.artist ?? "Start playing something in Spotify")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                if let collection = model.currentItem?.collection {
                    Text(collection)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                }
            }

            if let progress = model.currentItem?.progress {
                ProgressView(value: progress)
                    .tint(.white)
            }

            Toggle(
                "Show artwork on every desktop",
                isOn: Binding(
                    get: { model.isWallpaperEnabled },
                    set: { model.setWallpaperEnabled($0) }
                )
            )
            .toggleStyle(.switch)

            HStack {
                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshing)

                if let spotifyURL = model.currentItem?.spotifyURL {
                    Link(destination: spotifyURL) {
                        Label("Open in Spotify", systemImage: "arrow.up.right")
                    }
                }
            }
            .buttonStyle(.bordered)

            Divider()

            HStack {
                Label("Artwork supplied by Spotify", systemImage: "music.note")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                Spacer()
                Button("Disconnect") {
                    model.disconnect()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.62))
            }

            if let errorMessage = model.errorMessage {
                errorView(errorMessage)
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.48))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Text("Instant with Spotify for Mac · 30-second fallback")
            Spacer()
            if let lastUpdated = model.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative)")
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.62))
        .frame(maxWidth: 860)
    }

    private var statusColor: Color {
        switch model.connectionState {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return Color(red: 0.20, green: 0.82, blue: 0.47)
        }
    }
}
