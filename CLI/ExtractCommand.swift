import ArgumentParser
import Foundation
import TheTrimmerCore

struct ExtractCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract a time range from video (keep only start to end)"
    )

    @Argument(help: "Input video file")
    var input: String

    @Option(name: .long, help: "Start time (e.g. 0:30, 30, 0:00:30)")
    var start: String

    @Option(name: .long, help: "End time (e.g. 2:15, 135, 0:02:15)")
    var end: String

    @Option(name: .long, help: "Output file path (default: auto-generated)")
    var output: String?

    @Flag(name: .long, help: "Overwrite original file")
    var overwrite = false

    @Flag(name: .long, help: "Suppress output except errors")
    var quiet = false

    func run() async throws {
        let url = URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(input)")
        }

        let startSeconds = try TimeParser.parse(start)
        let endSeconds = try TimeParser.parse(end)
        let runner = FFmpegRunner()

        if !quiet {
            print("Extracting \(TimeParser.format(startSeconds)) → \(TimeParser.format(endSeconds)) from \(url.lastPathComponent)")
        }

        let outputURL = output.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        let result = try await runner.extractRange(input: url, start: startSeconds, end: endSeconds, output: outputURL, overwrite: overwrite)

        if !quiet {
            print("Output: \(result.path)")
        }
    }
}
