import Testing
import Foundation
@testable import TheTrimmer

@Suite("FFmpegTrimmer Tests")
struct FFmpegTrimmerTests {

    @Test("keepLeft builds correct ffmpeg arguments")
    func keepLeftCommand() {
        let trimmer = FFmpegTrimmer()
        let args = trimmer.buildArguments(
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
        let trimmer = FFmpegTrimmer()
        let args = trimmer.buildArguments(
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

    @Test("outputPath appends _trimmed suffix")
    func outputPathBasic() {
        let trimmer = FFmpegTrimmer()
        let input = URL(fileURLWithPath: "/Users/me/old-recordings/2025-08-20 10-40-03.mov")
        let output = trimmer.generateOutputPath(for: input)
        #expect(output.lastPathComponent == "2025-08-20 10-40-03_trimmed.mov")
        #expect(output.deletingLastPathComponent().path == "/Users/me/old-recordings")
    }

    @Test("outputPath increments when _trimmed already exists")
    func outputPathIncrement() {
        let trimmer = FFmpegTrimmer()
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let input = tmpDir.appendingPathComponent("video.mov")
        FileManager.default.createFile(atPath: input.path, contents: nil)

        let existing = tmpDir.appendingPathComponent("video_trimmed.mov")
        FileManager.default.createFile(atPath: existing.path, contents: nil)

        let output = trimmer.generateOutputPath(for: input)
        #expect(output.lastPathComponent == "video_trimmed_2.mov")
    }

    @Test("ffmpegPath points to existing binary")
    func ffmpegExists() {
        let trimmer = FFmpegTrimmer()
        #expect(FileManager.default.fileExists(atPath: trimmer.ffmpegPath))
    }
}
