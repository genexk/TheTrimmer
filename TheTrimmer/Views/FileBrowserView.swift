import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var viewModel: FileBrowserViewModel
    let onSelectFile: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { viewModel.openFolder() }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh file list")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            if viewModel.roots.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Add a folder to browse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $viewModel.selectedFile) {
                    ForEach(viewModel.roots) { root in
                        FileTreeNode(node: root, selectedFile: viewModel.selectedFile, onSelectFile: onSelectFile)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

struct FileTreeNode: View {
    let node: FileNode
    let selectedFile: URL?
    let onSelectFile: (URL) -> Void

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                if let children = node.children {
                    ForEach(children) { child in
                        FileTreeNode(node: child, selectedFile: selectedFile, onSelectFile: onSelectFile)
                    }
                }
            } label: {
                Label(node.name, systemImage: "folder.fill")
                    .foregroundStyle(.primary)
            }
        } else {
            HStack {
                Label(node.name, systemImage: "film")
                Spacer()
            }
            .contentShape(Rectangle())
            .background(selectedFile == node.url ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(4)
            .onTapGesture {
                onSelectFile(node.url)
            }
        }
    }
}
