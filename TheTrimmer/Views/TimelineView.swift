import SwiftUI

struct TimelineView: View {
    @Binding var currentTime: Double
    @Binding var trimPoint: Double
    let duration: Double
    let onSeek: (Double) -> Void

    private let trackHeight: CGFloat = 8
    private let markerWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackHeight)

                // Playback progress
                if duration > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: max(0, width * currentTime / duration), height: trackHeight)
                }

                // Trim marker
                if duration > 0 {
                    trimMarker(width: width)
                }
            }
            .frame(height: 30)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / width))
                        let time = fraction * duration
                        onSeek(time)
                    }
            )
        }
        .frame(height: 30)
    }

    @ViewBuilder
    private func trimMarker(width: CGFloat) -> some View {
        let xPos = width * trimPoint / duration

        Rectangle()
            .fill(Color.red)
            .frame(width: markerWidth, height: 24)
            .overlay(
                Triangle()
                    .fill(Color.red)
                    .frame(width: 12, height: 8)
                    .offset(y: -16),
                alignment: .top
            )
            .position(x: xPos, y: 15)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard duration > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / width))
                        trimPoint = fraction * duration
                    }
            )
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
