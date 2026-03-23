import Foundation

struct FileNode: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    let isDirectory: Bool
    let fileSize: Int64
    let creationDate: Date?
    var children: [FileNode]?

    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]
    static let audioExtensions: Set<String> = ["mp3", "wav", "flac", "aac", "m4a", "ogg"]
    static let mediaExtensions: Set<String> = videoExtensions.union(audioExtensions)

    var isVideo: Bool {
        Self.videoExtensions.contains(url.pathExtension.lowercased())
    }

    var isAudio: Bool {
        Self.audioExtensions.contains(url.pathExtension.lowercased())
    }

    var isMedia: Bool {
        Self.mediaExtensions.contains(url.pathExtension.lowercased())
    }

    var formattedSize: String {
        if fileSize < 1024 * 1024 {
            return String(format: "%.0f KB", Double(fileSize) / 1024)
        } else if fileSize < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(fileSize) / 1024 / 1024)
        } else {
            return String(format: "%.2f GB", Double(fileSize) / 1024 / 1024 / 1024)
        }
    }
}

enum SortField: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
}

enum SortOrder {
    case ascending, descending
    mutating func toggle() {
        self = (self == .ascending) ? .descending : .ascending
    }
}
