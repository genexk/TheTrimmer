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
