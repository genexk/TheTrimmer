# TheTrimmer

Fast macOS media trimmer using ffmpeg stream copy — O(1) speed, no re-encoding.

Includes a **GUI app** (SwiftUI) and a **CLI tool** for automation. Supports both video and audio files.

## How It Works

TheTrimmer uses ffmpeg's **stream copy** mode (`-c copy`) to trim videos without re-encoding. This means:

- **Instant trimming** — a 2-hour 4K video trims in under a second
- **Zero quality loss** — no generation loss since frames are copied as-is
- **Any format** — works with MOV, MP4, MKV, AVI, WebM, M4V, MP3, WAV, FLAC, AAC, M4A, OGG

The tradeoff is that cuts happen at the nearest keyframe, so trim points may be off by a fraction of a second (typically <0.5s for most video files). Audio files trim with sample-level precision.

## Install CLI via Homebrew

```bash
brew tap genexk/tools
brew install trimmer
```

Or build from source:

```bash
git clone https://github.com/genexk/TheTrimmer.git
cd TheTrimmer
swift build -c release
# Binary at .build/release/trimmer-cli
```

## CLI Usage

### `trimmer info` — Show media metadata

```bash
trimmer info video.mov
trimmer info song.mp3
```

Output:
```
File:       video.mov
Format:     QuickTime / MOV
Duration:   0:09.633
Resolution: 1668x1080
Codec:      h264
Size:       3.4 MB
```

For audio files:
```
File:       song.mp3
Format:     MP3
Duration:   3:42.100
Codec:      mp3
Sample Rate: 44.1 kHz
Channels:   Stereo
Size:       5.2 MB
```

### `trimmer extract` — Keep a time range

Extract only the portion between start and end timestamps:

```bash
trimmer extract video.mov --start 0:30 --end 2:15
```

### `trimmer trim` — Keep one side of a point

Split the video at a timestamp and keep either the left or right half:

```bash
# Keep everything before 1:30
trimmer trim video.mov --keep-left --at 1:30

# Keep everything after 1:30
trimmer trim video.mov --keep-right --at 1:30
```

### `trimmer cut` — Remove a time range

Remove a section from the middle and concatenate the remaining parts:

```bash
trimmer cut video.mov --start 0:30 --end 2:15
```

This creates a new file with the 0:30–2:15 section removed. Uses ffmpeg's concat demuxer, still stream copy (no re-encoding).

### Time formats

All commands accept flexible time formats:

| Format | Example | Seconds |
|--------|---------|---------|
| `H:MM:SS` | `1:30:00` | 5400 |
| `M:SS` | `1:30` | 90 |
| Seconds | `90` | 90 |
| Decimal | `90.5` | 90.5 |

### Common options

```
--output path.mov    Custom output path (default: auto-generated)
--overwrite          Replace the original file
--quiet              Suppress output except errors
```

## GUI App

```bash
swift run TheTrimmer
```

A native macOS SwiftUI app for visual media trimming:

- **File browser sidebar** — navigate directories, sort by name/date/size, auto-refreshes when files change on disk
- **Video player** — built-in AVPlayer with play/pause, draggable progress bar for seeking
- **Audio waveform** — audio files display an interactive waveform visualization with playback position indicator
- **Trim marker** — drag the red arrow to set a trim point, then click "Trim Left" or "Trim Right"
- **Resizable panels** — drag the divider between sidebar and video player to resize
- **Overwrite toggle** — optionally replace the original file instead of creating a new one
- **Auto-generated filenames** — output files are named `video_trimmed.mov`, `video_trimmed_2.mov`, etc.

## Architecture

```
Package.swift
├── TheTrimmerCore/        Shared library (no GUI dependencies)
│   ├── FFmpegRunner       ffmpeg/ffprobe process management
│   ├── TimeParser         Parse "1:30", "90.5" → seconds
│   ├── TrimMode           keepLeft / keepRight enum
│   └── TrimError          Error types
├── TheTrimmer/            GUI app (SwiftUI, depends on Core)
│   ├── Views/             VideoPlayer, Timeline, FileBrowser
│   ├── ViewModels/        TrimmerViewModel, FileBrowserViewModel
│   └── Services/          FFmpegTrimmer (thin wrapper)
├── CLI/                   CLI tool (ArgumentParser, depends on Core)
│   ├── InfoCommand        Video metadata display
│   ├── TrimCommand        Keep left/right of a point
│   ├── ExtractCommand     Keep a time range
│   └── CutCommand         Remove a time range (concat)
└── TheTrimmerTests/       Unit tests (Swift Testing)
```

## Requirements

- macOS 14+ (Sonoma)
- [ffmpeg](https://formulae.brew.sh/formula/ffmpeg) (`brew install ffmpeg`)
- Xcode 15+ or Swift 5.10+ (for building from source)

## License

MIT
