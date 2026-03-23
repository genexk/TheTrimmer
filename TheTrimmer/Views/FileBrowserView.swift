import SwiftUI

struct FileBrowserView: View {
    @ObservedObject var viewModel: FileBrowserViewModel
    let onSelectFile: (URL) -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: { viewModel.openFolder() }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)

                if viewModel.canGoUp {
                    Button(action: { viewModel.goUp() }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .help("Go up one directory")
                }

                Spacer()

                Button(action: { viewModel.showDetails.toggle() }) {
                    Image(systemName: viewModel.showDetails ? "list.bullet" : "list.dash")
                }
                .buttonStyle(.borderless)
                .help(viewModel.showDetails ? "Hide details" : "Show details")

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh file list")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Current directory path
            if let dir = viewModel.currentDirectory {
                HStack {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(dir.lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }

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
                // Column headers
                if viewModel.showDetails {
                    HStack(spacing: 0) {
                        sortButton(.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        sortButton(.date)
                            .frame(width: 110, alignment: .leading)
                        sortButton(.size)
                            .frame(width: 65, alignment: .trailing)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))

                    Divider()
                }

                // File list
                List(viewModel.sortedFiles, selection: $viewModel.selectedFile) { file in
                    fileRow(file)
                        .tag(file.url)
                }
                .listStyle(.sidebar)
                .onChange(of: viewModel.selectedFile) { _, newValue in
                    guard let url = newValue else { return }
                    if let file = viewModel.sortedFiles.first(where: { $0.url == url }) {
                        if file.isDirectory {
                            viewModel.selectedFile = nil
                            viewModel.navigateTo(url)
                        } else {
                            onSelectFile(url)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ file: FileNode) -> some View {
        let icon = file.isDirectory ? "folder" : (file.isAudio ? "waveform" : "film")
        if viewModel.showDetails {
            HStack(spacing: 0) {
                Label(file.name, systemImage: icon)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !file.isDirectory {
                    if let date = file.creationDate {
                        Text(Self.dateFormatter.string(from: date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)
                    } else {
                        Text("—")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 110, alignment: .leading)
                    }

                    Text(file.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 65, alignment: .trailing)
                } else {
                    Spacer()
                        .frame(width: 175)
                }
            }
        } else {
            Label(file.name, systemImage: icon)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func sortButton(_ field: SortField) -> some View {
        Button(action: { viewModel.toggleSort(field) }) {
            Text(field.rawValue + viewModel.sortIndicator(for: field))
                .fontWeight(viewModel.sortField == field ? .semibold : .regular)
        }
        .buttonStyle(.plain)
    }
}
