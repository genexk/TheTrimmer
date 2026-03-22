import Testing
import Foundation
@testable import TheTrimmer

@Suite("TrimmerViewModel Tests")
struct TrimmerViewModelTests {

    @Test("initial state has no file loaded")
    func initialState() async {
        let vm = await TrimmerViewModel()
        await #expect(vm.fileURL == nil)
        await #expect(vm.duration == 0)
        await #expect(vm.trimPoint == 0)
        await #expect(vm.canTrim == false)
    }

    @Test("canTrim is false when trimPoint is at boundary")
    func canTrimBoundary() async {
        let vm = await TrimmerViewModel()
        await MainActor.run {
            vm.duration = 100.0
            vm.fileURL = URL(fileURLWithPath: "/tmp/test.mov")
            vm.trimPoint = 0.0
        }
        await #expect(vm.canTrim == false)

        await MainActor.run { vm.trimPoint = 100.0 }
        await #expect(vm.canTrim == false)

        await MainActor.run { vm.trimPoint = 50.0 }
        await #expect(vm.canTrim == true)
    }

    @Test("statusMessage starts as Ready")
    func statusReady() async {
        let vm = await TrimmerViewModel()
        await #expect(vm.statusMessage == "Ready")
    }
}
