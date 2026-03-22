import SwiftUI

struct ContentView: View {
    @StateObject private var trimmerVM = TrimmerViewModel()
    @StateObject private var browserVM = FileBrowserViewModel()

    var body: some View {
        HSplitView {
            FileBrowserView(viewModel: browserVM) { url in
                browserVM.selectedFile = url
                trimmerVM.loadFile(url)
            }
            .frame(minWidth: 200, idealWidth: 400, maxWidth: 600)

            VideoDetailView(viewModel: trimmerVM)
                .frame(minWidth: 500)
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
