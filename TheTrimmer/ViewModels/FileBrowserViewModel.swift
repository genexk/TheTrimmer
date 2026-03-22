import SwiftUI
import UniformTypeIdentifiers

@MainActor
class FileBrowserViewModel: ObservableObject {
    @Published var roots: [FileNode] = []
    @Published var selectedFile: URL?
    @Published var sortField: SortField = .name
    @Published var sortOrder: SortOrder = .ascending
    @Published var showDetails: Bool = true

    private let fileManager = FileManager.default

    /// Flat list of all video files from all roots, sorted
    var sortedFiles: [FileNode] {
        let allFiles = roots.flatMap { collectVideoFiles($0) }
        return allFiles.sorted { a, b in
            let result: Bool
            switch sortField {
            case .name:
                result = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .date:
                let da = a.creationDate ?? .distantPast
                let db = b.creationDate ?? .distantPast
                result = da < db
            case .size:
                result = a.fileSize < b.fileSize
            }
            return sortOrder == .ascending ? result : !result
        }
    }

    private func collectVideoFiles(_ node: FileNode) -> [FileNode] {
        if !node.isDirectory { return [node] }
        return node.children?.flatMap { collectVideoFiles($0) } ?? []
    }

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
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return FileNode(id: url, name: url.lastPathComponent, url: url, isDirectory: true, fileSize: 0, creationDate: nil, children: [])
        }

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey])
            let isDir = values?.isDirectory ?? false
            if isDir {
                let subNode = scanDirectory(item)
                if subNode.children?.isEmpty == false {
                    children.append(subNode)
                }
            } else if FileNode.videoExtensions.contains(item.pathExtension.lowercased()) {
                let size = Int64(values?.fileSize ?? 0)
                let created = values?.creationDate
                children.append(FileNode(id: item, name: item.lastPathComponent, url: item, isDirectory: false, fileSize: size, creationDate: created, children: nil))
            }
        }

        return FileNode(id: url, name: url.lastPathComponent, url: url, isDirectory: true, fileSize: 0, creationDate: nil, children: children)
    }

    func refresh() {
        let currentRoots = roots.map(\.url)
        roots = currentRoots.map { scanDirectory($0) }
    }

    func toggleSort(_ field: SortField) {
        if sortField == field {
            sortOrder.toggle()
        } else {
            sortField = field
            sortOrder = .ascending
        }
    }

    func sortIndicator(for field: SortField) -> String {
        guard sortField == field else { return "" }
        return sortOrder == .ascending ? " ▲" : " ▼"
    }
}
