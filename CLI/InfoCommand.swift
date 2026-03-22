import ArgumentParser
import Foundation
import TheTrimmerCore

struct InfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show video file information"
    )

    @Argument(help: "Input video file")
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
        print("Resolution: \(info.resolution)")
        print("Codec:      \(info.codec)")
        print("Size:       \(info.formattedSize)")
    }
}
