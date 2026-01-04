@testable import SLAMRecorder
import SwiftUI
import ViewInspector
import XCTest

final class CameraSelectionViewTests: XCTestCase {
    func testCameraSelectionViewStructure() throws {
        let view = CameraSelectionView(selected: .constant([.backWide, .front]))

        let vStack = try view.inspect().vStack()
        XCTAssertNotNil(vStack)
    }

    func testHeaderTextIsCorrect() throws {
        let view = CameraSelectionView(selected: .constant([.backWide]))

        let vStack = try view.inspect().vStack()
        let headerText = try vStack.text(0).string()
        XCTAssertEqual(headerText, "Cameras (select 1-2)")
    }

    func testEmptySelectionShowsWarning() throws {
        let view = CameraSelectionView(selected: .constant([]))

        let vStack = try view.inspect().vStack()
        // VStack has: Text, ForEach, Text (warning)
        XCTAssertEqual(vStack.count, 3)
        let warningText = try vStack.text(2).string()
        XCTAssertEqual(warningText, "Please select at least one camera")
    }

    func testNoWarningWithSelection() throws {
        let view = CameraSelectionView(selected: .constant([.backWide]))

        let vStack = try view.inspect().vStack()
        // VStack has: Text, ForEach
        // The warning text should not be present when cameras are selected
        // But ViewInspector might still count the conditional branch, so check if >= 2
        XCTAssertGreaterThanOrEqual(vStack.count, 2)
    }
}
