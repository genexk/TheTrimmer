import Foundation
import os

private let logger = Logger(subsystem: "com.local.TheTrimmer", category: "FFmpegTrimmer")

enum TrimMode {
    case keepLeft
    case keepRight
}

struct FFmpegTrimmer {
    let ffmpegPath = "/opt/homebrew/bin/ffmpeg"

    func buildArguments(input: URL, output: URL, mode: TrimMode, trimPoint: Double) -> [String] {
        let timeStr = String(format: "%.3f", trimPoint)
        switch mode {
        case .keepLeft:
            return ["-nostdin", "-i", input.path, "-to", timeStr, "-c", "copy", "-y", output.path]
        case .keepRight:
            return ["-nostdin", "-ss", timeStr, "-i", input.path, "-c", "copy", "-y", output.path]
        }
    }

    func generateOutputPath(for input: URL) -> URL {
        let dir = input.deletingLastPathComponent()
        let stem = input.deletingPathExtension().lastPathComponent
        let ext = input.pathExtension

        let candidate = dir.appendingPathComponent("\(stem)_trimmed.\(ext)")
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        var counter = 2
        while true {
            let numbered = dir.appendingPathComponent("\(stem)_trimmed_\(counter).\(ext)")
            if !FileManager.default.fileExists(atPath: numbered.path) {
                return numbered
            }
            counter += 1
        }
    }

    func trim(input: URL, mode: TrimMode, trimPoint: Double, overwrite: Bool) async throws -> URL {
        let output: URL
        if overwrite {
            output = input.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString)_tmp.\(input.pathExtension)")
        } else {
            output = generateOutputPath(for: input)
        }

        let args = buildArguments(input: input, output: output, mode: mode, trimPoint: trimPoint)
        logger.info("Starting trim: ffmpeg \(args.joined(separator: " "), privacy: .public)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = args

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice  // prevent ffmpeg waiting for terminal input

        let stderrData = Task.detached { () -> Data in
            stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }

        // CRITICAL: set terminationHandler BEFORE run() to avoid race condition
        // where process finishes before handler is registered
        let startTime = CFAbsoluteTimeGetCurrent()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                logger.info("ffmpeg exited with status \(proc.terminationStatus) in \(String(format: "%.2f", elapsed))s")
                continuation.resume()
            }
            do {
                try process.run()
                logger.info("ffmpeg process launched (pid: \(process.processIdentifier))")
            } catch {
                logger.error("Failed to launch ffmpeg: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            }
        }

        guard process.terminationStatus == 0 else {
            let errorData = await stderrData.value
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("ffmpeg failed: \(errorMsg, privacy: .public)")
            try? FileManager.default.removeItem(at: output)
            throw TrimError.ffmpegFailed(errorMsg)
        }

        let outputSize = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
        logger.info("Trim complete: \(output.lastPathComponent) (\(outputSize / 1024 / 1024)MB)")

        if overwrite {
            let backup = input.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString)_backup.\(input.pathExtension)")
            try FileManager.default.moveItem(at: input, to: backup)
            try FileManager.default.moveItem(at: output, to: input)
            try? FileManager.default.removeItem(at: backup)
            logger.info("Overwrite complete — original replaced")
            return input
        }

        return output
    }
}

enum TrimError: LocalizedError {
    case ffmpegFailed(String)
    case ffmpegNotFound

    var errorDescription: String? {
        switch self {
        case .ffmpegFailed(let msg): return "ffmpeg failed: \(msg)"
        case .ffmpegNotFound: return "ffmpeg not found at /opt/homebrew/bin/ffmpeg. Install with: brew install ffmpeg"
        }
    }
}
