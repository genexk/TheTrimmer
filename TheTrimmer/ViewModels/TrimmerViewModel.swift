import SwiftUI
import AVFoundation
import Combine
import os
import TheTrimmerCore

private let logger = Logger(subsystem: "com.local.TheTrimmer", category: "TrimmerVM")

@MainActor
class TrimmerViewModel: ObservableObject {
    @Published var fileURL: URL?
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var trimPoint: Double = 0
    @Published var isPlaying: Bool = false
    @Published var overwriteOriginal: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var isTrimming: Bool = false

    private let trimmer = FFmpegTrimmer()
    private var timeObserver: Any?
    @Published var player: AVPlayer?

    var canTrim: Bool {
        guard fileURL != nil, duration > 0 else { return false }
        return trimPoint > 0 && trimPoint < duration
    }

    private func cleanup() {
        logger.debug("Cleaning up player state")
        if let existing = timeObserver {
            player?.removeTimeObserver(existing)
            timeObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        currentTime = 0
        duration = 0
        trimPoint = 0
    }

    func loadFile(_ url: URL) {
        logger.info("Loading file: \(url.lastPathComponent, privacy: .public)")
        cleanup()

        fileURL = url
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        Task {
            let dur = try? await asset.load(.duration)
            if let dur {
                self.duration = dur.seconds
                self.trimPoint = dur.seconds / 2
                logger.info("Duration loaded: \(String(format: "%.1f", dur.seconds))s, trim point set to \(String(format: "%.1f", dur.seconds / 2))s")
            } else {
                logger.warning("Failed to load duration for \(url.lastPathComponent, privacy: .public)")
            }
        }

        statusMessage = "Loaded: \(url.lastPathComponent)"
        setupTimeObserver()
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            logger.debug("Paused")
        } else {
            player.play()
            logger.debug("Playing")
        }
        isPlaying.toggle()
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    func trimLeft() async {
        await performTrim(mode: .keepLeft)
    }

    func trimRight() async {
        await performTrim(mode: .keepRight)
    }

    private func performTrim(mode: TrimMode) async {
        guard let fileURL, canTrim else {
            logger.warning("Trim skipped: fileURL=\(self.fileURL?.lastPathComponent ?? "nil", privacy: .public), canTrim=\(self.canTrim)")
            return
        }
        guard FileManager.default.fileExists(atPath: trimmer.ffmpegPath) else {
            logger.error("ffmpeg not found at \(self.trimmer.ffmpegPath)")
            statusMessage = "Error: ffmpeg not found. Install with: brew install ffmpeg"
            return
        }

        isTrimming = true
        let modeLabel = mode == .keepLeft ? "Keep Left" : "Keep Right"
        logger.info("Starting trim: \(modeLabel, privacy: .public) at \(String(format: "%.3f", self.trimPoint))s on \(fileURL.lastPathComponent, privacy: .public), overwrite=\(self.overwriteOriginal)")
        statusMessage = "Trimming (\(modeLabel))..."

        do {
            let result = try await trimmer.trim(
                input: fileURL,
                mode: mode,
                trimPoint: trimPoint,
                overwrite: overwriteOriginal
            )
            logger.info("Trim succeeded: \(result.lastPathComponent, privacy: .public)")
            statusMessage = "Done: \(result.lastPathComponent)"
            if overwriteOriginal {
                loadFile(result)
            }
        } catch {
            logger.error("Trim failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Error: \(error.localizedDescription)"
        }

        isTrimming = false
    }

    private func setupTimeObserver() {
        if let existing = timeObserver {
            player?.removeTimeObserver(existing)
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }
}
