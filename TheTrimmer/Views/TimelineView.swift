import SwiftUI

struct TimelineView: View {
    @Binding var currentTime: Double
    @Binding var trimPoint: Double
    let duration: Double
    let onSeek: (Double) -> Void

    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 14
    private let trimBarWidth: CGFloat = 2
    private let trimArrowSize: CGFloat = 16
    private let trimHitArea: CGFloat = 30

    @State private var isDraggingProgress = false
    @State private var isDraggingTrim = false

    var body: some View {
        VStack(spacing: 0) {
            // Trim arrow row — sits above the track
            GeometryReader { geo in
                let width = geo.size.width
                if duration > 0 {
                    ZStack {
                        // Invisible background so the ZStack fills the width
                        Color.clear

                        // Draggable trim arrow
                        ZStack {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: trimHitArea, height: 20)
                            Triangle()
                                .fill(isDraggingTrim ? Color.red : Color.red.opacity(0.85))
                                .frame(width: trimArrowSize, height: 10)
                        }
                        .contentShape(Rectangle())
                        .position(x: width * trimPoint / duration, y: 10)
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    guard duration > 0 else { return }
                                    isDraggingTrim = true
                                    let fraction = max(0, min(1, value.location.x / width))
                                    trimPoint = fraction * duration
                                }
                                .onEnded { _ in
                                    isDraggingTrim = false
                                }
                        )
                    }
                }
            }
            .frame(height: 20)

            // Track row — fully draggable for seeking
            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: trackHeight)

                    // Playback progress fill
                    if duration > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: max(0, width * currentTime / duration), height: trackHeight)
                    }

                    // Trim marker vertical line (non-interactive)
                    if duration > 0 {
                        Rectangle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: trimBarWidth, height: 18)
                            .position(x: width * trimPoint / duration, y: 9)
                            .allowsHitTesting(false)
                    }

                    // Progress thumb (visual only — the track gesture handles dragging)
                    if duration > 0 {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: thumbSize, height: thumbSize)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .scaleEffect(isDraggingProgress ? 1.3 : 1.0)
                            .position(x: max(0, width * currentTime / duration), y: 9)
                            .allowsHitTesting(false)
                            .animation(.easeOut(duration: 0.15), value: isDraggingProgress)
                    }
                }
                .frame(height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard duration > 0 else { return }
                            isDraggingProgress = true
                            let fraction = max(0, min(1, value.location.x / width))
                            onSeek(fraction * duration)
                        }
                        .onEnded { _ in
                            isDraggingProgress = false
                        }
                )
            }
            .frame(height: 18)
        }
        .frame(height: 38)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}
