import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "com.local.TheTrimmer", category: "ContentView")

struct ContentView: View {
    @StateObject private var trimmerVM = TrimmerViewModel()
    @StateObject private var browserVM = FileBrowserViewModel()
    @State private var sidebarWidth: CGFloat = 380
    @State private var dragStartWidth: CGFloat = 0

    private let minSidebar: CGFloat = 200
    private let maxSidebar: CGFloat = 600
    private let dividerWidth: CGFloat = 8

    var body: some View {
        HStack(spacing: 0) {
            // Left panel — file browser
            FileBrowserView(viewModel: browserVM) { url in
                browserVM.selectedFile = url
                trimmerVM.loadFile(url)
            }
            .frame(width: sidebarWidth)
            .arrowCursor()

            // Divider with grip indicator
            ZStack {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)

                // Grip dots
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(width: dividerWidth)
            .contentShape(Rectangle())
            .resizeCursor()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartWidth == 0 {
                            dragStartWidth = sidebarWidth
                        }
                        let newWidth = dragStartWidth + value.translation.width
                        sidebarWidth = min(maxSidebar, max(minSidebar, newWidth))
                    }
                    .onEnded { _ in
                        dragStartWidth = 0
                    }
            )

            // Right panel — video detail
            VideoDetailView(viewModel: trimmerVM)
                .frame(minWidth: 500)
                .arrowCursor()
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            logger.info("App launching — setting activation policy")
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let defaultDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("old-recordings")
            if FileManager.default.fileExists(atPath: defaultDir.path) {
                logger.info("Auto-loading default directory: \(defaultDir.path, privacy: .public)")
                browserVM.addRoot(defaultDir)
            } else {
                logger.info("Default directory not found: \(defaultDir.path, privacy: .public)")
            }
        }
    }
}
