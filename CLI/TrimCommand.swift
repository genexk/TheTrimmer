import ArgumentParser
import Foundation
import TheTrimmerCore

struct TrimCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trim",
        abstract: "Trim media at a point (keep left or right)"
    )

    @Argument(help: "Input video file")
    var input: String

    @Option(name: .long, help: "Time point to trim at (e.g. 1:30, 90, 0:45.5)")
    var at: String

    @Flag(name: .long, help: "Keep content before the trim point")
    var keepLeft = false

    @Flag(name: .long, help: "Keep content after the trim point")
    var keepRight = false

    @Option(name: .long, help: "Output file path (default: auto-generated)")
    var output: String?

    @Flag(name: .long, help: "Overwrite original file")
    var overwrite = false

    @Flag(name: .long, help: "Suppress output except errors")
    var quiet = false

    func validate() throws {
        guard keepLeft != keepRight else {
            throw ValidationError("Specify exactly one of --keep-left or --keep-right")
        }
    }

    func run() async throws {
        let url = URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(input)")
        }

        let trimPoint = try TimeParser.parse(at)
        let mode: TrimMode = keepLeft ? .keepLeft : .keepRight
        let runner = FFmpegRunner()

        if !quiet {
            let side = keepLeft ? "left" : "right"
            print("Trimming \(url.lastPathComponent) — keep \(side) of \(TimeParser.format(trimPoint))")
        }

        var result: URL
        if let outputPath = output {
            let outputURL = URL(fileURLWithPath: (outputPath as NSString).expandingTildeInPath)
            let args = runner.buildArguments(input: url, output: outputURL, mode: mode, trimPoint: trimPoint)
            try await runner.runFFmpeg(arguments: args)
            result = outputURL
        } else {
            result = try await runner.trim(input: url, mode: mode, trimPoint: trimPoint, overwrite: overwrite)
        }

        if !quiet {
            print("Output: \(result.path)")
        }
    }
}
