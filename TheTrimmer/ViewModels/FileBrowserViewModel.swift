import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.local.TheTrimmer", category: "FileBrowser")

@MainActor
class FileBrowserViewModel: ObservableObject {
    @Published var roots: [FileNode] = []
    @Published var currentDirectory: URL?
    @Published var currentFiles: [FileNode] = []
    @Published var selectedFile: URL?
    @Published var sortField: SortField = .name
    @Published var sortOrder: SortOrder = .ascending
    @Published var showDetails: Bool = true

    private let fileManager = FileManager.default
    private var directoryWatcher: DirectoryWatcher?

    /// Files in the current directory, sorted
    var sortedFiles: [FileNode] {
        currentFiles.sorted { a, b in
            // Directories first
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
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

    /// Whether we can navigate up from the current directory
    var canGoUp: Bool {
        guard let current = currentDirectory else { return false }
        return roots.contains { $0.url != current && current.path.hasPrefix($0.url.path) }
            || roots.count > 1
            || (roots.count == 1 && roots.first?.url != current)
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing media files"

        if panel.runModal() == .OK, let url = panel.url {
            addRoot(url)
        }
    }

    func addRoot(_ url: URL) {
        guard !roots.contains(where: { $0.url == url }) else {
            logger.debug("Root already added: \(url.lastPathComponent, privacy: .public)")
            return
        }
        logger.info("Adding root directory: \(url.path, privacy: .public)")
        let node = scanDirectoryShallow(url)
        roots.append(node)
        navigateTo(url)
    }

    func navigateTo(_ url: URL) {
        logger.info("Navigating to: \(url.lastPathComponent, privacy: .public)")
        currentDirectory = url
        reloadCurrentDirectory()
        watchCurrentDirectory()
    }

    func goUp() {
        guard let current = currentDirectory else { return }
        let parent = current.deletingLastPathComponent()
        logger.info("Going up from \(current.lastPathComponent, privacy: .public) to \(parent.lastPathComponent, privacy: .public)")
        if roots.contains(where: { parent.path.hasPrefix($0.url.path) || parent == $0.url }) {
            navigateTo(parent)
        } else {
            stopWatching()
            currentDirectory = nil
            currentFiles = roots
        }
    }

    /// Reload files in the current directory, preserving the selection
    private func reloadCurrentDirectory() {
        guard let dir = currentDirectory else { return }
        let previousSelection = selectedFile
        let children = scanDirectoryShallow(dir).children ?? []
        currentFiles = children

        // Preserve selection if the file still exists
        if let prev = previousSelection, children.contains(where: { $0.url == prev }) {
            selectedFile = prev
        }

        let dirs = children.filter(\.isDirectory).count
        let files = children.count - dirs
        logger.info("Directory contents: \(files) files, \(dirs) subdirectories")
    }

    // MARK: - File system watching

    private func watchCurrentDirectory() {
        stopWatching()
        guard let dir = currentDirectory else { return }

        logger.debug("Starting file watcher for \(dir.lastPathComponent, privacy: .public)")
        directoryWatcher = DirectoryWatcher(url: dir) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                logger.debug("File system change detected in \(dir.lastPathComponent, privacy: .public)")
                self.reloadCurrentDirectory()
            }
        }
    }

    private func stopWatching() {
        directoryWatcher?.stop()
        directoryWatcher = nil
    }

    /// Scan a directory for immediate children (video files + subdirectories with video content)
    func scanDirectoryShallow(_ url: URL) -> FileNode {
        var children: [FileNode] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return FileNode(id: url, name: url.lastPathComponent, url: url, isDirectory: true, fileSize: 0, creationDate: nil, children: [])
        }

        for item in contents {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey])
            let isDir = values?.isDirectory ?? false
            if isDir {
                if directoryHasMedia(item) {
                    children.append(FileNode(id: item, name: item.lastPathComponent, url: item, isDirectory: true, fileSize: 0, creationDate: values?.creationDate, children: nil))
                }
            } else if FileNode.mediaExtensions.contains(item.pathExtension.lowercased()) {
                let size = Int64(values?.fileSize ?? 0)
                let created = values?.creationDate
                children.append(FileNode(id: item, name: item.lastPathComponent, url: item, isDirectory: false, fileSize: size, creationDate: created, children: nil))
            }
        }

        return FileNode(id: url, name: url.lastPathComponent, url: url, isDirectory: true, fileSize: 0, creationDate: nil, children: children)
    }

    private func directoryHasMedia(_ url: URL) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return false
        }
        for item in contents {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir { return true }
            if FileNode.mediaExtensions.contains(item.pathExtension.lowercased()) { return true }
        }
        return false
    }

    func refresh() {
        if currentDirectory != nil {
            reloadCurrentDirectory()
        } else {
            let currentRoots = roots.map(\.url)
            roots = currentRoots.map { scanDirectoryShallow($0) }
            currentFiles = roots
        }
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

    deinit {
        directoryWatcher?.stop()
    }
}

// MARK: - Directory Watcher using DispatchSource

/// Watches a directory for file system changes using GCD's DISPATCH_SOURCE_TYPE_VNODE.
final class DirectoryWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    init(url: URL, onChange: @escaping () -> Void) {
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            logger.warning("Failed to open directory for watching: \(url.path, privacy: .public)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )

        // Debounce: wait 0.5s after last event before firing
        var debounceItem: DispatchWorkItem?
        source.setEventHandler {
            debounceItem?.cancel()
            let item = DispatchWorkItem {
                onChange()
            }
            debounceItem = item
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: item)
        }

        source.setCancelHandler { [fileDescriptor] in
            close(fileDescriptor)
        }

        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
