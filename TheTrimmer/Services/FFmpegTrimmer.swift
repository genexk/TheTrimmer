import Foundation
import os
import TheTrimmerCore

private let logger = Logger(subsystem: "com.local.TheTrimmer", category: "FFmpegTrimmer")

struct FFmpegTrimmer {
    let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
    private let runner = FFmpegRunner()

    func buildArguments(input: URL, output: URL, mode: TrimMode, trimPoint: Double) -> [String] {
        runner.buildArguments(input: input, output: output, mode: mode, trimPoint: trimPoint)
    }

    func generateOutputPath(for input: URL) -> URL {
        runner.generateOutputPath(for: input)
    }

    func trim(input: URL, mode: TrimMode, trimPoint: Double, overwrite: Bool) async throws -> URL {
        try await runner.trim(input: input, mode: mode, trimPoint: trimPoint, overwrite: overwrite)
    }
}
