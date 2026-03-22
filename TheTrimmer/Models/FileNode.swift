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
