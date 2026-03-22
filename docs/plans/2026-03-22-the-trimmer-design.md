# The Trimmer — Design Document

**Date**: 2026-03-22
**Status**: Approved

## Overview

A single-window SwiftUI macOS app for trimming video files at O(1) speed using ffmpeg stream copy (no re-encoding). Designed for trimming ~155 MOV screen recordings in ~/old-recordings.

## Architecture

Three layers:
1. **View Layer** — SwiftUI window with AVPlayer video, custom timeline slider, controls
2. **ViewModel** — `TrimmerViewModel` (ObservableObject) managing playback state, trim point, trim execution
3. **Trim Engine** — Shells out to `ffmpeg -c copy` via `Process`

## UI Layout

```
┌──────────────────────────────────────────────────┐
│  The Trimmer                                     │
│  ┌──────────────────────────────────────────────┐│
│  │                                              ││
│  │              AVPlayer Video                  ││
│  │            (drag & drop zone)                ││
│  │                                              ││
│  └──────────────────────────────────────────────┘│
│  ▶/❚❚   00:12:34 / 01:23:45                     │
│  ┌──────────────────────────────────────────────┐│
│  │████████████▼─────────────────────────────────││
│  └──────────────────────────────────────────────┘│
│         ↑ trim marker (draggable)                │
│                                                  │
│  [✂ Keep Left]  [Keep Right ✂]   ☐ Overwrite    │
│                                                  │
│  Status: Ready                                   │
└──────────────────────────────────────────────────┘
```

## Components

| Component | Role |
|-----------|------|
| `VideoPlayerView` | Wraps `AVPlayer` in `NSViewRepresentable`. Handles drag-and-drop. |
| `TimelineView` | Custom slider: current position + independent trim marker handle. |
| `TrimmerViewModel` | Holds `currentTime`, `duration`, `trimPoint`, `overwriteOriginal`. Exposes `trimLeft()`/`trimRight()`. |
| `FFmpegTrimmer` | Runs ffmpeg via `Process` with `-c copy`. |

## Trim Logic (O(1))

- **Keep Left**: `ffmpeg -i input.mov -to <trimPoint> -c copy output.mov`
- **Keep Right**: `ffmpeg -ss <trimPoint> -i input.mov -c copy output.mov`
  - `-ss` before `-i` = input seeking (nearest keyframe, near-instant)
  - `-c copy` = no decode/re-encode, just remux

**Keyframe caveat**: Cut point may be off by ~1s. Acceptable for screen recordings.

## File Naming

- **New file mode** (default): `filename_trimmed.mov`, incrementing `_trimmed_2` etc. if exists
- **Overwrite mode**: Trim to temp file, atomic rename to replace original

## File Opening

1. Drag and drop onto video area
2. Open button → `NSOpenPanel` (filtered to video types)

## Error Handling

- ffmpeg not found → alert with install instructions
- Trim failure → show ffmpeg stderr in status label
- Disable trim buttons when no file loaded or trim at boundary

## Project Structure

```
TheTrimmer/
├── TheTrimmerApp.swift
├── ContentView.swift
├── Views/
│   ├── VideoPlayerView.swift
│   └── TimelineView.swift
├── ViewModels/
│   └── TrimmerViewModel.swift
└── Services/
    └── FFmpegTrimmer.swift
```

## Tech Stack

- Swift + SwiftUI + AVKit (macOS 14+)
- ffmpeg 8.0.1 at /opt/homebrew/bin/ffmpeg (stream copy only)
- Xcode project (Swift Package Manager, no external deps)
