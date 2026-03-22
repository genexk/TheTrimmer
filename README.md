# TheTrimmer

Fast macOS video trimmer using ffmpeg stream copy — O(1) speed, no re-encoding.

Includes a **GUI app** (SwiftUI) and a **CLI tool** for automation.

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

```bash
# Show video info
trimmer info video.mov

# Extract a range (keep only 0:30 to 2:15)
trimmer extract video.mov --start 0:30 --end 2:15

# Trim at a point (keep everything before 1:30)
trimmer trim video.mov --keep-left --at 1:30

# Cut out a range (remove 0:30 to 2:15, keep the rest)
trimmer cut video.mov --start 0:30 --end 2:15
```

### Time formats

All commands accept these time formats:

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

Features:
- Resizable split view with file browser sidebar
- Per-directory navigation with sortable columns
- Auto-refresh when files change on disk
- Draggable progress bar and trim marker
- Trim left/right of marker with one click

## Requirements

- macOS 14+ (Sonoma)
- [ffmpeg](https://formulae.brew.sh/formula/ffmpeg) (`brew install ffmpeg`)

## License

MIT
