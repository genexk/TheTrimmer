import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct VideoDetailView: View {
    @ObservedObject var viewModel: TrimmerViewModel
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if let player = viewModel.player {
                    VideoPlayerView(player: player)
                } else {
                    placeholderView
                }
            }
            .frame(minHeight: 300)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isDragOver ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers)
            }

            HStack {
                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.player == nil)
                .keyboardShortcut(.space, modifiers: [])

                Text(formatTime(viewModel.currentTime))
                    .monospacedDigit()
                    .frame(width: 80, alignment: .trailing)

                Text("/")
                    .foregroundStyle(.secondary)

                Text(formatTime(viewModel.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)

                Spacer()
            }

            TimelineView(
                currentTime: $viewModel.currentTime,
                trimPoint: $viewModel.trimPoint,
                duration: viewModel.duration,
                onSeek: { viewModel.seek(to: $0) }
            )

            if viewModel.duration > 0 {
                HStack(spacing: 8) {
                    Text("Trim point: \(formatTime(viewModel.trimPoint))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        viewModel.trimPoint = viewModel.currentTime
                    } label: {
                        Label("Snap to playhead", systemImage: "arrow.down.to.line")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Set trim point to current playback position (S)")
                    .keyboardShortcut("s", modifiers: [])
                }
            }

            HStack(spacing: 16) {
                Button {
                    Task { await viewModel.trimLeft() }
                } label: {
                    Label("Keep Left", systemImage: "scissors")
                }
                .disabled(!viewModel.canTrim || viewModel.isTrimming)

                Button {
                    Task { await viewModel.trimRight() }
                } label: {
                    Label("Keep Right", systemImage: "scissors")
                }
                .disabled(!viewModel.canTrim || viewModel.isTrimming)

                Spacer()

                Toggle("Overwrite original", isOn: $viewModel.overwriteOriginal)
            }

            HStack {
                if viewModel.isTrimming {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        }
        .padding()
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select a video from the sidebar\nor drop one here")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                viewModel.loadFile(url)
            }
        }
        return true
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
