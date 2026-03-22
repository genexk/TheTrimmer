import Foundation
import os

private let logger = Logger(subsystem: "com.local.TheTrimmer", category: "FFmpegRunner")

public struct FFmpegRunner {
    public let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
    public let ffprobePath = "/opt/homebrew/bin/ffprobe"

    public init() {}

    // MARK: - Argument builders

    public func buildArguments(input: URL, output: URL, mode: TrimMode, trimPoint: Double) -> [String] {
        let timeStr = String(format: "%.3f", trimPoint)
        switch mode {
        case .keepLeft:
            return ["-nostdin", "-i", input.path, "-to", timeStr, "-c", "copy", "-y", output.path]
        case .keepRight:
            return ["-nostdin", "-ss", timeStr, "-i", input.path, "-c", "copy", "-y", output.path]
        }
    }

    public func buildExtractArguments(input: URL, output: URL, start: Double, end: Double) -> [String] {
        let startStr = String(format: "%.3f", start)
        let endStr = String(format: "%.3f", end)
        return ["-nostdin", "-ss", startStr, "-i", input.path, "-to", endStr, "-c", "copy", "-y", output.path]
    }

    // MARK: - Output path

    public func generateOutputPath(for input: URL, suffix: String = "trimmed") -> URL {
        let dir = input.deletingLastPathComponent()
        let stem = input.deletingPathExtension().lastPathComponent
        let ext = input.pathExtension

        let candidate = dir.appendingPathComponent("\(stem)_\(suffix).\(ext)")
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        var counter = 2
        while true {
            let numbered = dir.appendingPathComponent("\(stem)_\(suffix)_\(counter).\(ext)")
            if !FileManager.default.fileExists(atPath: numbered.path) {
                return numbered
            }
            counter += 1
        }
    }

    // MARK: - Core execution

    public func runFFmpeg(arguments: [String]) async throws {
        logger.info("Running: ffmpeg \(arguments.joined(separator: " "), privacy: .public)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = arguments

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        let stderrData = Task.detached { () -> Data in
            stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }

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
            throw TrimError.ffmpegFailed(errorMsg)
        }
    }

    // MARK: - High-level operations

    public func trim(input: URL, mode: TrimMode, trimPoint: Double, overwrite: Bool) async throws -> URL {
        let output: URL
        if overwrite {
            output = input.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString)_tmp.\(input.pathExtension)")
        } else {
            output = generateOutputPath(for: input)
        }

        let args = buildArguments(input: input, output: output, mode: mode, trimPoint: trimPoint)
        do {
            try await runFFmpeg(arguments: args)
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }

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

    public func extractRange(input: URL, start: Double, end: Double, output: URL? = nil, overwrite: Bool = false) async throws -> URL {
        guard start < end else {
            throw TrimError.invalidTimeRange("start (\(start)) must be less than end (\(end))")
        }

        let outputURL: URL
        if let output = output {
            outputURL = output
        } else if overwrite {
            outputURL = input.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString)_tmp.\(input.pathExtension)")
        } else {
            outputURL = generateOutputPath(for: input, suffix: "extracted")
        }

        let args = buildExtractArguments(input: input, output: outputURL, start: start, end: end)
        do {
            try await runFFmpeg(arguments: args)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }

        if overwrite {
            let backup = input.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString)_backup.\(input.pathExtension)")
            try FileManager.default.moveItem(at: input, to: backup)
            try FileManager.default.moveItem(at: outputURL, to: input)
            try? FileManager.default.removeItem(at: backup)
            return input
        }

        return outputURL
    }

    public func cutRange(input: URL, start: Double, end: Double, output: URL? = nil, overwrite: Bool = false) async throws -> URL {
        guard start < end else {
            throw TrimError.invalidTimeRange("start (\(start)) must be less than end (\(end))")
        }

        let finalOutput: URL
        if let output = output {
            finalOutput = output
        } else if overwrite {
            finalOutput = input.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString)_tmp.\(input.pathExtension)")
        } else {
            finalOutput = generateOutputPath(for: input, suffix: "cut")
        }

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let part1 = tmpDir.appendingPathComponent("part1.\(input.pathExtension)")
        let part2 = tmpDir.appendingPathComponent("part2.\(input.pathExtension)")

        // Part 1: start of file → cut start
        let args1 = ["-nostdin", "-i", input.path, "-to", String(format: "%.3f", start), "-c", "copy", "-y", part1.path]
        try await runFFmpeg(arguments: args1)

        // Part 2: cut end → end of file
        let args2 = ["-nostdin", "-ss", String(format: "%.3f", end), "-i", input.path, "-c", "copy", "-y", part2.path]
        try await runFFmpeg(arguments: args2)

        // Concat the two parts
        let listFile = tmpDir.appendingPathComponent("concat.txt")
        let listContent = "file '\(part1.path)'\nfile '\(part2.path)'\n"
        try listContent.write(to: listFile, atomically: true, encoding: .utf8)

        let concatArgs = ["-nostdin", "-f", "concat", "-safe", "0", "-i", listFile.path, "-c", "copy", "-y", finalOutput.path]
        do {
            try await runFFmpeg(arguments: concatArgs)
        } catch {
            try? FileManager.default.removeItem(at: finalOutput)
            throw error
        }

        if overwrite {
            let backup = input.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString)_backup.\(input.pathExtension)")
            try FileManager.default.moveItem(at: input, to: backup)
            try FileManager.default.moveItem(at: finalOutput, to: input)
            try? FileManager.default.removeItem(at: backup)
            return input
        }

        return finalOutput
    }

    // MARK: - Info

    public func getInfo(input: URL) async throws -> VideoInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            input.path
        ]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        let outputData = Task.detached { () -> Data in
            stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }

        let data = await outputData.value
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let format = json["format"] as? [String: Any] ?? [:]
        let streams = json["streams"] as? [[String: Any]] ?? []
        let videoStream = streams.first { ($0["codec_type"] as? String) == "video" }

        let durationStr = format["duration"] as? String ?? videoStream?["duration"] as? String ?? "0"
        let duration = Double(durationStr) ?? 0

        let fileSize = Int64(format["size"] as? String ?? "0") ?? 0

        return VideoInfo(
            duration: duration,
            codec: videoStream?["codec_name"] as? String ?? "unknown",
            width: videoStream?["width"] as? Int ?? 0,
            height: videoStream?["height"] as? Int ?? 0,
            fileSize: fileSize,
            formatName: format["format_long_name"] as? String ?? format["format_name"] as? String ?? "unknown"
        )
    }
}

public struct VideoInfo {
    public let duration: Double
    public let codec: String
    public let width: Int
    public let height: Int
    public let fileSize: Int64
    public let formatName: String

    public var formattedDuration: String {
        TimeParser.format(duration)
    }

    public var formattedSize: String {
        let mb = Double(fileSize) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    public var resolution: String {
        "\(width)x\(height)"
    }
}
