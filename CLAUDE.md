# TheTrimmer — Project Instructions

## Overview
Native macOS SwiftUI media trimmer (video + audio) using ffmpeg stream copy for O(1) trimming.

## Build & Run
- `swift build` — compile
- `swift run` — launch the app
- `swift test` — run unit tests
- Log stream: `log stream --predicate 'subsystem == "com.local.TheTrimmer"' --level debug`

## Logging
Always use `os.Logger` for logging. Every file that has meaningful operations should have a logger:

```swift
import os
private let logger = Logger(subsystem: "com.local.TheTrimmer", category: "CategoryName")
```

### What to log
- **info**: File loads, navigation events, trim start/complete, directory scans, app lifecycle events
- **debug**: State changes (play/pause), cleanup operations, gesture interactions
- **warning**: Unexpected but recoverable situations (failed to load duration, missing files)
- **error**: Failures that affect user-visible behavior (ffmpeg failed, file not found)

### Privacy
- Use `privacy: .public` for file names and paths (local app, no sensitive data)
- Never log file contents or raw binary data

## Architecture
- `TheTrimmerApp.swift` — App entry point
- `ContentView.swift` — Main layout with custom resizable split view
- `Views/` — SwiftUI views (FileBrowserView, VideoDetailView, VideoPlayerView, AudioWaveformView, TimelineView)
- `ViewModels/` — TrimmerViewModel (player + trim state), FileBrowserViewModel (directory navigation)
- `Services/FFmpegTrimmer.swift` — ffmpeg process management with stream copy
- `Models/FileNode.swift` — File tree model with metadata

## Key Patterns
- Create new `AVPlayer` per file load — `replaceCurrentItem` doesn't reliably trigger SwiftUI view updates
- Set `Process.terminationHandler` BEFORE `process.run()` to avoid race condition
- Use `-nostdin` + `FileHandle.nullDevice` for stdin when launching CLI tools from GUI
- `NSApp.setActivationPolicy(.regular)` for proper foreground app behavior via `swift run`

## Targets
- macOS 14+ (Sonoma)
- Swift 5.10, SwiftUI
- ffmpeg via Homebrew (`/opt/homebrew/bin/ffmpeg`)
