@testable import SLAMRecorder
import SwiftUI
import ViewInspector
import XCTest

final class ContentViewTests: XCTestCase {
    func testContentViewStructure() throws {
        let view = ContentView()
        let zStack = try view.inspect().zStack()
        XCTAssertNotNil(zStack)
    }

    func testRecordingModePickerExists() throws {
        let view = ContentView()
        let zStack = try view.inspect().zStack()
        let vstack = try zStack.vStack(1)
        let picker = try vstack.picker(0)
        XCTAssertNotNil(picker)
    }

    func testZStackHasTwoElements() throws {
        let view = ContentView()
        let zStack = try view.inspect().zStack()
        // ZStack should have 2 children: the conditional view (ARView or MultiCam) and the VStack overlay
        XCTAssertEqual(zStack.count, 2)
    }
}
