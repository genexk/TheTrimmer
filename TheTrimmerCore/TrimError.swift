import Foundation

public enum TrimError: LocalizedError {
    case ffmpegFailed(String)
    case ffmpegNotFound
    case invalidTimeRange(String)

    public var errorDescription: String? {
        switch self {
        case .ffmpegFailed(let msg): return "ffmpeg failed: \(msg)"
        case .ffmpegNotFound: return "ffmpeg not found at /opt/homebrew/bin/ffmpeg. Install with: brew install ffmpeg"
        case .invalidTimeRange(let msg): return "Invalid time range: \(msg)"
        }
    }
}
