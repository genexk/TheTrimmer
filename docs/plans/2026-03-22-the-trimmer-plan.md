# The Trimmer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use braze-superpowers:subagent-driven-development (recommended) or braze-superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI video trimmer that uses ffmpeg stream copy for O(1) trimming without re-encoding.

**Architecture:** Single-window SwiftUI app with NavigationSplitView — file browser sidebar on the left, AVPlayer video + timeline + trim controls on the right. FFmpegTrimmer service shells out to `ffmpeg -c copy`. ViewModel (ObservableObject) glues state together. File switching is efficient: old AVPlayerItem is replaced (not stacked), time observers are cleaned up before reload.

**Tech Stack:** Swift, SwiftUI, AVKit, AVFoundation, ffmpeg 8.0.1 (CLI via Process)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `TheTrimmer/TheTrimmerApp.swift` | App entry point, single WindowGroup |
| `TheTrimmer/ContentView.swift` | NavigationSplitView: file browser sidebar + video/trim detail pane |
| `TheTrimmer/Views/FileBrowserView.swift` | Directory tree with expandable folders, video file filtering, selection |
| `TheTrimmer/Views/VideoPlayerView.swift` | NSViewRepresentable wrapping AVPlayerView |
| `TheTrimmer/Views/TimelineView.swift` | Custom SwiftUI view: playback position slider + independent trim marker |
| `TheTrimmer/Views/VideoDetailView.swift` | Right pane: video player, playback controls, timeline, trim buttons, status |
| `TheTrimmer/ViewModels/TrimmerViewModel.swift` | ObservableObject: playback state, file loading, trim orchestration |
| `TheTrimmer/ViewModels/FileBrowserViewModel.swift` | ObservableObject: directory scanning, file tree, selection state |
| `TheTrimmer/Models/FileNode.swift` | Identifiable model for directory tree (folder vs video file) |
| `TheTrimmer/Services/FFmpegTrimmer.swift` | Runs ffmpeg via Process, output path generation, overwrite logic |
| `TheTrimmerTests/FFmpegTrimmerTests.swift` | Unit tests for FFmpegTrimmer (command building, path generation) |
| `TheTrimmerTests/TrimmerViewModelTests.swift` | Unit tests for ViewModel (state transitions, trim point validation) |

---

### Task 1: Create Xcode Project Skeleton

**Files:**
- Create: `TheTrimmer.xcodeproj` (via xcodebuild or Xcode CLI)
- Create: `TheTrimmer/TheTrimmerApp.swift`
- Create: `TheTrimmer/ContentView.swift`

- [ ] **Step 1: Create the Xcode project using Swift Package structure**

Since we don't have Xcode CLI easily scriptable, create a Swift Package-based app. Create the directory structure:

```bash
cd ~/projects/TheTrimmer
mkdir -p TheTrimmer/Views TheTrimmer/ViewModels TheTrimmer/Services
mkdir -p TheTrimmerTests
```

- [ ] **Step 2: Create Package.swift**

> **Note on Swift Package vs Xcode project**: SwiftUI `@main` apps work from `swift run` on macOS —
> the `@main` attribute configures `NSApplication` correctly. You won't get a dock icon or proper
> app name in the menu bar, but windows, file panels, drag-and-drop, and AVPlayer all work.
> For a polished `.app` bundle, open `Package.swift` in Xcode and use Product > Archive.

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TheTrimmer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TheTrimmer",
            path: "TheTrimmer",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "TheTrimmer/Info.plist"])
            ]
        ),
        .testTarget(
            name: "TheTrimmerTests",
            dependencies: ["TheTrimmer"],
            path: "TheTrimmerTests"
        ),
    ]
)
```

- [ ] **Step 2b: Create Info.plist for proper app identity**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>The Trimmer</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.TheTrimmer</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
```

Save to `TheTrimmer/Info.plist`.

- [ ] **Step 3: Create TheTrimmerApp.swift**

```swift
import SwiftUI

@main
struct TheTrimmerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1100, height: 700)
    }
}
```

- [ ] **Step 4: Create placeholder ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("The Trimmer")
                .font(.largeTitle)
            Text("Drop a video file here")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 5: Build to verify project compiles**

```bash
cd ~/projects/TheTrimmer
swift build 2>&1
```

Expected: Build Succeeded

- [ ] **Step 6: Commit**

```bash
git init && git add -A && git commit -m "feat: scaffold TheTrimmer SwiftUI app skeleton"
```

---

### Task 2: FFmpegTrimmer Service (with tests)

**Files:**
- Create: `TheTrimmer/Services/FFmpegTrimmer.swift`
- Create: `TheTrimmerTests/FFmpegTrimmerTests.swift`

This is the core O(1) trim engine. We test command building and output path generation without running ffmpeg.

- [ ] **Step 1: Write failing tests for FFmpegTrimmer**

```swift
// TheTrimmerTests/FFmpegTrimmerTests.swift
import Testing
import Foundation
@testable import TheTrimmer

@Suite("FFmpegTrimmer Tests")
struct FFmpegTrimmerTests {

    // MARK: - Command Building

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
            "-ss", "120.000",
            "-i", "/tmp/video.mov",
            "-c", "copy",
            "-y",
            "/tmp/video_trimmed.mov"
        ])
    }

    // MARK: - Output Path Generation

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
        // Use a temp directory to test collision handling
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let input = tmpDir.appendingPathComponent("video.mov")
        FileManager.default.createFile(atPath: input.path, contents: nil)

        // Create the _trimmed file so it collides
        let existing = tmpDir.appendingPathComponent("video_trimmed.mov")
        FileManager.default.createFile(atPath: existing.path, contents: nil)

        let output = trimmer.generateOutputPath(for: input)
        #expect(output.lastPathComponent == "video_trimmed_2.mov")
    }

    // MARK: - ffmpeg Path Validation

    @Test("ffmpegPath points to existing binary")
    func ffmpegExists() {
        let trimmer = FFmpegTrimmer()
        #expect(FileManager.default.fileExists(atPath: trimmer.ffmpegPath))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/projects/TheTrimmer
swift test 2>&1
```

Expected: compilation errors — `FFmpegTrimmer` not defined.

- [ ] **Step 3: Implement FFmpegTrimmer**

```swift
// TheTrimmer/Services/FFmpegTrimmer.swift
import Foundation

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
            return ["-i", input.path, "-to", timeStr, "-c", "copy", "-y", output.path]
        case .keepRight:
            return ["-ss", timeStr, "-i", input.path, "-c", "copy", "-y", output.path]
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = args

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice

        // Read stderr asynchronously to avoid pipe buffer deadlock
        let stderrData = Task.detached { () -> Data in
            stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }

        try process.run()

        // Wait without blocking the cooperative thread pool
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        guard process.terminationStatus == 0 else {
            let errorData = await stderrData.value
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            try? FileManager.default.removeItem(at: output)
            throw TrimError.ffmpegFailed(errorMsg)
        }

        if overwrite {
            let backup = input.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString)_backup.\(input.pathExtension)")
            try FileManager.default.moveItem(at: input, to: backup)
            try FileManager.default.moveItem(at: output, to: input)
            try? FileManager.default.removeItem(at: backup)
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd ~/projects/TheTrimmer
swift test 2>&1
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add FFmpegTrimmer service with O(1) stream copy trim"
```

---

### Task 3: TrimmerViewModel

**Files:**
- Create: `TheTrimmer/ViewModels/TrimmerViewModel.swift`
- Create: `TheTrimmerTests/TrimmerViewModelTests.swift`

- [ ] **Step 1: Write failing tests for TrimmerViewModel**

```swift
// TheTrimmerTests/TrimmerViewModelTests.swift
import Testing
import Foundation
@testable import TheTrimmer

@Suite("TrimmerViewModel Tests")
struct TrimmerViewModelTests {

    @Test("initial state has no file loaded")
    func initialState() async {
        let vm = await TrimmerViewModel()
        await #expect(vm.fileURL == nil)
        await #expect(vm.duration == 0)
        await #expect(vm.trimPoint == 0)
        await #expect(vm.canTrim == false)
    }

    @Test("canTrim is false when trimPoint is at boundary")
    func canTrimBoundary() async {
        let vm = await TrimmerViewModel()
        await MainActor.run {
            vm.duration = 100.0
            vm.fileURL = URL(fileURLWithPath: "/tmp/test.mov")
            vm.trimPoint = 0.0
        }
        await #expect(vm.canTrim == false)

        await MainActor.run { vm.trimPoint = 100.0 }
        await #expect(vm.canTrim == false)

        await MainActor.run { vm.trimPoint = 50.0 }
        await #expect(vm.canTrim == true)
    }

    @Test("statusMessage starts as Ready")
    func statusReady() async {
        let vm = await TrimmerViewModel()
        await #expect(vm.statusMessage == "Ready")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/projects/TheTrimmer
swift test 2>&1
```

Expected: compilation errors — `TrimmerViewModel` not defined.

- [ ] **Step 3: Implement TrimmerViewModel**

```swift
// TheTrimmer/ViewModels/TrimmerViewModel.swift
import SwiftUI
import AVFoundation
import Combine

@MainActor
class TrimmerViewModel: ObservableObject {
    @Published var fileURL: URL?
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var trimPoint: Double = 0
    @Published var isPlaying: Bool = false
    @Published var overwriteOriginal: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var isTrimming: Bool = false

    private let trimmer = FFmpegTrimmer()
    private var timeObserver: Any?
    var player: AVPlayer?

    var canTrim: Bool {
        guard fileURL != nil, duration > 0 else { return false }
        return trimPoint > 0 && trimPoint < duration
    }

    func loadFile(_ url: URL) {
        fileURL = url
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        Task {
            let dur = try? await asset.load(.duration)
            if let dur {
                self.duration = dur.seconds
                self.trimPoint = dur.seconds / 2
            }
        }

        currentTime = 0
        isPlaying = false
        statusMessage = "Loaded: \(url.lastPathComponent)"
        setupTimeObserver()
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    func trimLeft() async {
        await performTrim(mode: .keepLeft)
    }

    func trimRight() async {
        await performTrim(mode: .keepRight)
    }

    private func performTrim(mode: TrimMode) async {
        guard let fileURL, canTrim else { return }
        guard FileManager.default.fileExists(atPath: trimmer.ffmpegPath) else {
            statusMessage = "Error: ffmpeg not found. Install with: brew install ffmpeg"
            return
        }

        isTrimming = true
        let modeLabel = mode == .keepLeft ? "Keep Left" : "Keep Right"
        statusMessage = "Trimming (\(modeLabel))..."

        do {
            let result = try await trimmer.trim(
                input: fileURL,
                mode: mode,
                trimPoint: trimPoint,
                overwrite: overwriteOriginal
            )
            statusMessage = "Done: \(result.lastPathComponent)"
            if overwriteOriginal {
                loadFile(result)
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }

        isTrimming = false
    }

    private func setupTimeObserver() {
        if let existing = timeObserver {
            player?.removeTimeObserver(existing)
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd ~/projects/TheTrimmer
swift test 2>&1
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add TrimmerViewModel with playback state and trim orchestration"
```

---

### Task 4: VideoPlayerView (AVPlayer NSViewRepresentable)

**Files:**
- Create: `TheTrimmer/Views/VideoPlayerView.swift`

No unit tests for this — it's pure AppKit/SwiftUI glue. Tested visually.

- [ ] **Step 1: Implement VideoPlayerView**

```swift
// TheTrimmer/Views/VideoPlayerView.swift
import SwiftUI
import AVKit

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
cd ~/projects/TheTrimmer
swift build 2>&1
```

Expected: Build Succeeded

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add VideoPlayerView AVPlayer wrapper"
```

---

### Task 5: TimelineView (Custom Timeline with Trim Marker)

**Files:**
- Create: `TheTrimmer/Views/TimelineView.swift`

- [ ] **Step 1: Implement TimelineView**

```swift
// TheTrimmer/Views/TimelineView.swift
import SwiftUI

struct TimelineView: View {
    @Binding var currentTime: Double
    @Binding var trimPoint: Double
    let duration: Double
    let onSeek: (Double) -> Void

    private let trackHeight: CGFloat = 8
    private let markerWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackHeight)

                // Playback progress
                if duration > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: max(0, width * currentTime / duration), height: trackHeight)
                }

                // Trim marker
                if duration > 0 {
                    trimMarker(width: width)
                }
            }
            .frame(height: 30)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / width))
                        let time = fraction * duration
                        onSeek(time)
                    }
            )
        }
        .frame(height: 30)
    }

    @ViewBuilder
    private func trimMarker(width: CGFloat) -> some View {
        let xPos = width * trimPoint / duration

        Rectangle()
            .fill(Color.red)
            .frame(width: markerWidth, height: 24)
            .overlay(
                Triangle()
                    .fill(Color.red)
                    .frame(width: 12, height: 8)
                    .offset(y: -16),
                alignment: .top
            )
            .position(x: xPos, y: 15)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard duration > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / width))
                        trimPoint = fraction * duration
                    }
            )
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
cd ~/projects/TheTrimmer
swift build 2>&1
```

Expected: Build Succeeded

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add TimelineView with playback slider and trim marker"
```

---

### Task 6: FileNode Model + FileBrowserViewModel

**Files:**
- Create: `TheTrimmer/Models/FileNode.swift`
- Create: `TheTrimmer/ViewModels/FileBrowserViewModel.swift`

- [ ] **Step 1: Create FileNode model**

```swift
// TheTrimmer/Models/FileNode.swift
import Foundation

struct FileNode: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?

    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]

    var isVideo: Bool {
        Self.videoExtensions.contains(url.pathExtension.lowercased())
    }
}
```

- [ ] **Step 2: Create FileBrowserViewModel**

```swift
// TheTrimmer/ViewModels/FileBrowserViewModel.swift
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class FileBrowserViewModel: ObservableObject {
    @Published var roots: [FileNode] = []
    @Published var selectedFile: URL?

    private let fileManager = FileManager.default

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing video files"

        if panel.runModal() == .OK, let url = panel.url {
            addRoot(url)
        }
    }

    func addRoot(_ url: URL) {
        guard !roots.contains(where: { $0.url == url }) else { return }
        let node = scanDirectory(url)
        roots.append(node)
    }

    func scanDirectory(_ url: URL) -> FileNode {
        var children: [FileNode] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else {
            return FileNode(id: url, name: url.lastPathComponent, url: url, isDirectory: true, children: [])
        }

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                let subNode = scanDirectory(item)
                // Only include directories that contain videos (directly or nested)
                if subNode.children?.isEmpty == false {
                    children.append(subNode)
                }
            } else if FileNode.videoExtensions.contains(item.pathExtension.lowercased()) {
                children.append(FileNode(id: item, name: item.lastPathComponent, url: item, isDirectory: false, children: nil))
            }
        }

        return FileNode(id: url, name: url.lastPathComponent, url: url, isDirectory: true, children: children)
    }

    func refresh() {
        let currentRoots = roots.map(\.url)
        roots = currentRoots.map { scanDirectory($0) }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
cd ~/projects/TheTrimmer
swift build 2>&1
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add FileNode model and FileBrowserViewModel"
```

---

### Task 7: FileBrowserView (Sidebar)

**Files:**
- Create: `TheTrimmer/Views/FileBrowserView.swift`

- [ ] **Step 1: Implement FileBrowserView**

```swift
// TheTrimmer/Views/FileBrowserView.swift
import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var viewModel: FileBrowserViewModel
    let onSelectFile: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: { viewModel.openFolder() }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh file list")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            if viewModel.roots.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Add a folder to browse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $viewModel.selectedFile) {
                    ForEach(viewModel.roots) { root in
                        FileTreeNode(node: root, selectedFile: viewModel.selectedFile, onSelectFile: onSelectFile)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

struct FileTreeNode: View {
    let node: FileNode
    let selectedFile: URL?
    let onSelectFile: (URL) -> Void

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                if let children = node.children {
                    ForEach(children) { child in
                        FileTreeNode(node: child, selectedFile: selectedFile, onSelectFile: onSelectFile)
                    }
                }
            } label: {
                Label(node.name, systemImage: "folder.fill")
                    .foregroundStyle(.primary)
            }
        } else {
            HStack {
                Label(node.name, systemImage: "film")
                Spacer()
            }
            .contentShape(Rectangle())
            .background(selectedFile == node.url ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(4)
            .onTapGesture {
                onSelectFile(node.url)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
cd ~/projects/TheTrimmer
swift build 2>&1
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add FileBrowserView sidebar with directory tree"
```

---

### Task 8: VideoDetailView (Right Pane — extracted from old ContentView)

**Files:**
- Create: `TheTrimmer/Views/VideoDetailView.swift`

- [ ] **Step 1: Implement VideoDetailView**

This is the video player + controls + timeline + trim buttons, extracted as a standalone view.

```swift
// TheTrimmer/Views/VideoDetailView.swift
import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct VideoDetailView: View {
    @ObservedObject var viewModel: TrimmerViewModel
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 12) {
            // Video Player
            ZStack {
                if let player = viewModel.player {
                    VideoPlayerView(player: player)
                } else {
                    placeholderView
                }
            }
            .frame(minHeight: 300)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isDragOver ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers)
            }

            // Playback controls
            HStack {
                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.player == nil)
                .keyboardShortcut(.space, modifiers: [])

                Text(formatTime(viewModel.currentTime))
                    .monospacedDigit()
                    .frame(width: 80, alignment: .trailing)

                Text("/")
                    .foregroundStyle(.secondary)

                Text(formatTime(viewModel.duration))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)

                Spacer()
            }

            // Timeline
            TimelineView(
                currentTime: $viewModel.currentTime,
                trimPoint: $viewModel.trimPoint,
                duration: viewModel.duration,
                onSeek: { viewModel.seek(to: $0) }
            )

            // Trim point label
            if viewModel.duration > 0 {
                Text("Trim point: \(formatTime(viewModel.trimPoint))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Trim controls
            HStack(spacing: 16) {
                Button {
                    Task { await viewModel.trimLeft() }
                } label: {
                    Label("Keep Left", systemImage: "scissors")
                }
                .disabled(!viewModel.canTrim || viewModel.isTrimming)

                Button {
                    Task { await viewModel.trimRight() }
                } label: {
                    Label("Keep Right", systemImage: "scissors")
                }
                .disabled(!viewModel.canTrim || viewModel.isTrimming)

                Spacer()

                Toggle("Overwrite original", isOn: $viewModel.overwriteOriginal)
            }

            // Status bar
            HStack {
                if viewModel.isTrimming {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        }
        .padding()
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Select a video from the sidebar\nor drop one here")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                viewModel.loadFile(url)
            }
        }
        return true
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
cd ~/projects/TheTrimmer
swift build 2>&1
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add VideoDetailView with player, timeline, and trim controls"
```

---

### Task 9: ContentView (NavigationSplitView Assembly)

**Files:**
- Modify: `TheTrimmer/ContentView.swift`

- [ ] **Step 1: Rewrite ContentView as NavigationSplitView**

```swift
// TheTrimmer/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var trimmerVM = TrimmerViewModel()
    @StateObject private var browserVM = FileBrowserViewModel()

    var body: some View {
        NavigationSplitView {
            FileBrowserView(viewModel: browserVM) { url in
                browserVM.selectedFile = url
                trimmerVM.loadFile(url)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            VideoDetailView(viewModel: trimmerVM)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            // Auto-load ~/old-recordings if it exists
            let defaultDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("old-recordings")
            if FileManager.default.fileExists(atPath: defaultDir.path) {
                browserVM.addRoot(defaultDir)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
cd ~/projects/TheTrimmer
swift build 2>&1
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: assemble ContentView with NavigationSplitView sidebar + detail"
```

---

### Task 10: Memory Leak Prevention in TrimmerViewModel

**Files:**
- Modify: `TheTrimmer/ViewModels/TrimmerViewModel.swift`

Ensure `loadFile()` properly cleans up before loading a new file: remove time observer, pause player, nil out old references.

- [ ] **Step 1: Update loadFile with cleanup**

Add a `cleanup()` method and call it at the start of `loadFile()`:

In `TrimmerViewModel.swift`, add before `loadFile`:

```swift
    private func cleanup() {
        if let existing = timeObserver {
            player?.removeTimeObserver(existing)
            timeObserver = nil
        }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        currentTime = 0
        duration = 0
        trimPoint = 0
    }
```

Then change `loadFile` to call `cleanup()` first:

```swift
    func loadFile(_ url: URL) {
        cleanup()

        fileURL = url
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        Task {
            let dur = try? await asset.load(.duration)
            if let dur {
                self.duration = dur.seconds
                self.trimPoint = dur.seconds / 2
            }
        }

        statusMessage = "Loaded: \(url.lastPathComponent)"
        setupTimeObserver()
    }
```

- [ ] **Step 2: Build and run tests**

```bash
cd ~/projects/TheTrimmer
swift test 2>&1
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "fix: prevent memory leaks on file switch with proper AVPlayer cleanup"
```

---

### Task 11: Manual Integration Test

- [ ] **Step 1: Run the app**

```bash
cd ~/projects/TheTrimmer
swift run 2>&1
```

- [ ] **Step 2: Manual test checklist**

1. App launches — sidebar shows `old-recordings` folder auto-loaded
2. Sidebar shows expandable directory tree with only video files
3. Click a video file in sidebar — loads in the right pane
4. Click a different video — switches instantly, no lag or crash
5. Rapidly click 10+ different files — no memory growth (check Activity Monitor)
6. "Add Folder" button opens folder picker, adds another root
7. Refresh button rescans directories
8. Play/Pause button and spacebar work
9. Timeline seeking and trim marker dragging work
10. "Keep Left" / "Keep Right" trim completes in seconds (O(1))
11. "Overwrite original" works correctly
12. Drag-and-drop a file onto the video area still works
13. Status bar shows correct messages throughout

- [ ] **Step 3: Fix any issues found during manual testing**

- [ ] **Step 4: Final commit**

```bash
git add -A && git commit -m "fix: polish from manual integration testing"
```
