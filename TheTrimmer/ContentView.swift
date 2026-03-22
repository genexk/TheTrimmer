import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("The Trimmer")
                .font(.largeTitle)
            Text("Drop a video file here")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
