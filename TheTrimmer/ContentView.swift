import SwiftUI

struct ContentView: View {
    @StateObject private var trimmerVM = TrimmerViewModel()
    @StateObject private var browserVM = FileBrowserViewModel()

    var body: some View {
        NavigationSplitView {
            FileBrowserView(viewModel: browserVM) { url in
                browserVM.selectedFile = url
                trimmerVM.loadFile(url)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            VideoDetailView(viewModel: trimmerVM)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            let defaultDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("old-recordings")
            if FileManager.default.fileExists(atPath: defaultDir.path) {
                browserVM.addRoot(defaultDir)
            }
        }
    }
}
