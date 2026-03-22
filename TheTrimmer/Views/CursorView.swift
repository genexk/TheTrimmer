import SwiftUI
import AppKit

/// NSView that overrides the cursor to arrow but passes all mouse events through.
struct ArrowCursorOverlay: NSViewRepresentable {
    func makeNSView(context: Context) -> PassthroughCursorNSView {
        PassthroughCursorNSView(cursor: .arrow)
    }

    func updateNSView(_ nsView: PassthroughCursorNSView, context: Context) {}
}

/// NSView that shows a resize-left-right cursor but passes all mouse events through.
struct ResizeCursorOverlay: NSViewRepresentable {
    func makeNSView(context: Context) -> PassthroughCursorNSView {
        PassthroughCursorNSView(cursor: .resizeLeftRight)
    }

    func updateNSView(_ nsView: PassthroughCursorNSView, context: Context) {}
}

/// An NSView that sets a cursor rect but returns nil from hitTest so all
/// mouse events pass through to the SwiftUI views underneath.
class PassthroughCursorNSView: NSView {
    private let cursor: NSCursor

    init(cursor: NSCursor) {
        self.cursor = cursor
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil  // pass all events through
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }
}

extension View {
    func arrowCursor() -> some View {
        self.overlay(ArrowCursorOverlay())
    }

    func resizeCursor() -> some View {
        self.overlay(ResizeCursorOverlay())
    }
}
