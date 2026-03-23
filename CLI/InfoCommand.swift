import ArgumentParser
import Foundation
import TheTrimmerCore

struct InfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show media file information (video or audio)"
    )

    @Argument(help: "Input media file")
    var input: String

    func run() async throws {
        let url = URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(input)")
        }

        let runner = FFmpegRunner()
        let info = try await runner.getInfo(input: url)

        print("File:       \(url.lastPathComponent)")
        print("Format:     \(info.formatName)")
        print("Duration:   \(info.formattedDuration)")
        if info.isAudioOnly {
            print("Codec:      \(info.audioCodec ?? info.codec)")
            if let sr = info.formattedSampleRate {
                print("Sample Rate: \(sr)")
            }
            if let ch = info.formattedChannels {
                print("Channels:   \(ch)")
            }
        } else {
            print("Resolution: \(info.resolution)")
            print("Codec:      \(info.codec)")
            if let ac = info.audioCodec {
                print("Audio:      \(ac)")
            }
        }
        print("Size:       \(info.formattedSize)")
    }
}
