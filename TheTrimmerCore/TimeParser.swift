import Foundation

public enum TimeParser {
    /// Parse time string to seconds.
    /// Formats: "1:30:00" (H:MM:SS), "1:30" (M:SS), "90" (seconds), "90.5" (decimal)
    public static func parse(_ string: String) throws -> Double {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw TrimError.invalidTimeRange("empty time string")
        }

        let parts = trimmed.split(separator: ":")
        let seconds: Double

        switch parts.count {
        case 1:
            // Plain seconds: "90" or "90.5"
            guard let value = Double(trimmed) else {
                throw TrimError.invalidTimeRange("'\(string)' is not a valid number")
            }
            seconds = value

        case 2:
            // M:SS — "1:30" → 90
            guard let minutes = Double(parts[0]),
                  let secs = Double(parts[1]) else {
                throw TrimError.invalidTimeRange("'\(string)' is not valid M:SS")
            }
            seconds = minutes * 60 + secs

        case 3:
            // H:MM:SS — "1:30:00" → 5400
            guard let hours = Double(parts[0]),
                  let minutes = Double(parts[1]),
                  let secs = Double(parts[2]) else {
                throw TrimError.invalidTimeRange("'\(string)' is not valid H:MM:SS")
            }
            seconds = hours * 3600 + minutes * 60 + secs

        default:
            throw TrimError.invalidTimeRange("'\(string)' has too many ':' separators")
        }

        guard seconds >= 0 else {
            throw TrimError.invalidTimeRange("time cannot be negative")
        }
        guard seconds.isFinite else {
            throw TrimError.invalidTimeRange("time must be finite")
        }

        return seconds
    }

    /// Format seconds to human-readable string (H:MM:SS.mmm)
    public static func format(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = seconds.truncatingRemainder(dividingBy: 60)
        if h > 0 {
            return String(format: "%d:%02d:%06.3f", h, m, s)
        } else {
            return String(format: "%d:%06.3f", m, s)
        }
    }
}
