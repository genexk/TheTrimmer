import Testing
import Foundation
@testable import TheTrimmerCore

@Suite("FFmpegRunner Tests")
struct FFmpegRunnerTests {

    @Test("keepLeft builds correct ffmpeg arguments")
    func keepLeftCommand() {
        let runner = FFmpegRunner()
        let args = runner.buildArguments(
            input: URL(fileURLWithPath: "/tmp/video.mov"),
            output: URL(fileURLWithPath: "/tmp/video_trimmed.mov"),
            mode: .keepLeft,
            trimPoint: 65.5
        )
        #expect(args == [
            "-nostdin",
            "-i", "/tmp/video.mov",
            "-to", "65.500",
            "-c", "copy",
            "-y",
            "/tmp/video_trimmed.mov"
        ])
    }

    @Test("keepRight puts -ss before -i for input seeking")
    func keepRightCommand() {
        let runner = FFmpegRunner()
        let args = runner.buildArguments(
            input: URL(fileURLWithPath: "/tmp/video.mov"),
            output: URL(fileURLWithPath: "/tmp/video_trimmed.mov"),
            mode: .keepRight,
            trimPoint: 120.0
        )
        #expect(args == [
            "-nostdin",
            "-ss", "120.000",
            "-i", "/tmp/video.mov",
            "-c", "copy",
            "-y",
            "/tmp/video_trimmed.mov"
        ])
    }

    @Test("extract builds correct ffmpeg arguments")
    func extractCommand() {
        let runner = FFmpegRunner()
        let args = runner.buildExtractArguments(
            input: URL(fileURLWithPath: "/tmp/video.mov"),
            output: URL(fileURLWithPath: "/tmp/video_extracted.mov"),
            start: 30.0,
            end: 90.5
        )
        #expect(args == [
            "-nostdin",
            "-ss", "30.000",
            "-i", "/tmp/video.mov",
            "-to", "90.500",
            "-c", "copy",
            "-y",
            "/tmp/video_extracted.mov"
        ])
    }

    @Test("outputPath appends _trimmed suffix")
    func outputPathBasic() {
        let runner = FFmpegRunner()
        let input = URL(fileURLWithPath: "/Users/me/old-recordings/2025-08-20 10-40-03.mov")
        let output = runner.generateOutputPath(for: input)
        #expect(output.lastPathComponent == "2025-08-20 10-40-03_trimmed.mov")
        #expect(output.deletingLastPathComponent().path == "/Users/me/old-recordings")
    }

    @Test("outputPath increments when _trimmed already exists")
    func outputPathIncrement() {
        let runner = FFmpegRunner()
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let input = tmpDir.appendingPathComponent("video.mov")
        FileManager.default.createFile(atPath: input.path, contents: nil)

        let existing = tmpDir.appendingPathComponent("video_trimmed.mov")
        FileManager.default.createFile(atPath: existing.path, contents: nil)

        let output = runner.generateOutputPath(for: input)
        #expect(output.lastPathComponent == "video_trimmed_2.mov")
    }

    @Test("ffmpegPath points to existing binary")
    func ffmpegExists() {
        let runner = FFmpegRunner()
        #expect(FileManager.default.fileExists(atPath: runner.ffmpegPath))
    }
}
