import SwiftUI
import AVFoundation
import os

private let logger = Logger(subsystem: "com.local.TheTrimmer", category: "AudioWaveform")

struct AudioWaveformView: View {
    let player: AVPlayer?
    let currentTime: Double
    let duration: Double

    @State private var samples: [Float] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if samples.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Loading waveform...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Canvas { context, size in
                        let barCount = samples.count
                        guard barCount > 0 else { return }
                        let barWidth = size.width / CGFloat(barCount)
                        let midY = size.height / 2

                        for (i, sample) in samples.enumerated() {
                            let amplitude = CGFloat(sample) * midY * 0.9
                            let x = CGFloat(i) * barWidth
                            let rect = CGRect(
                                x: x,
                                y: midY - amplitude,
                                width: max(barWidth - 0.5, 0.5),
                                height: amplitude * 2
                            )
                            context.fill(Path(rect), with: .color(.cyan.opacity(0.7)))
                        }

                        // Playback position
                        if duration > 0 {
                            let posX = size.width * currentTime / duration
                            let line = Path { p in
                                p.move(to: CGPoint(x: posX, y: 0))
                                p.addLine(to: CGPoint(x: posX, y: size.height))
                            }
                            context.stroke(line, with: .color(.white), lineWidth: 1.5)
                        }
                    }
                }
            }
        }
        .onChange(of: player?.currentItem?.asset) { _, _ in
            loadWaveform()
        }
        .onAppear {
            loadWaveform()
        }
    }

    private func loadWaveform() {
        guard let asset = player?.currentItem?.asset else {
            samples = []
            return
        }

        Task.detached(priority: .userInitiated) {
            let loaded = await readSamples(from: asset, targetCount: 500)
            await MainActor.run {
                samples = loaded
            }
        }
    }

    private func readSamples(from asset: AVAsset, targetCount: Int) async -> [Float] {
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else {
                logger.warning("No audio track found")
                return []
            }

            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            reader.add(output)
            reader.startReading()

            var allSamples: [Int16] = []
            while let buffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(buffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)
                _ = data.withUnsafeMutableBytes { ptr in
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
                }
                data.withUnsafeBytes { rawPtr in
                    let int16Ptr = rawPtr.bindMemory(to: Int16.self)
                    allSamples.append(contentsOf: int16Ptr)
                }
            }

            guard !allSamples.isEmpty else { return [] }

            // Downsample to targetCount bins
            let samplesPerBin = max(allSamples.count / targetCount, 1)
            var result: [Float] = []
            for i in 0..<targetCount {
                let start = i * samplesPerBin
                let end = min(start + samplesPerBin, allSamples.count)
                guard start < allSamples.count else { break }
                var maxVal: Int16 = 0
                for j in start..<end {
                    let abs = allSamples[j] < 0 ? -allSamples[j] : allSamples[j]
                    if abs > maxVal { maxVal = abs }
                }
                result.append(Float(maxVal) / Float(Int16.max))
            }

            logger.info("Waveform loaded: \(allSamples.count) samples → \(result.count) bars")
            return result
        } catch {
            logger.error("Failed to read audio samples: \(error.localizedDescription)")
            return []
        }
    }
}
