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
                ScrollViewReader { proxy in
                    List(viewModel.sortedFiles, selection: $viewModel.selectedFile) { file in
                        fileRow(file)
                            .tag(file.url)
                    }
                    .listStyle(.sidebar)
                    .onChange(of: viewModel.selectedFile) { _, newValue in
                        if let url = newValue {
                            onSelectFile(url)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fileRow(_ file: FileNode) -> some View {
        if viewModel.showDetails {
            HStack(spacing: 0) {
                Label(file.name, systemImage: "film")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
            }
        } else {
            Label(file.name, systemImage: "film")
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
