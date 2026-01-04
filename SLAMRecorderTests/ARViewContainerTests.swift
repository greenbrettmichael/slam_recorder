@testable import SLAMRecorder
import SwiftUI
import ViewInspector
import XCTest

final class ARViewContainerTests: XCTestCase {
    var logger: SLAMLogger!

    override func setUp() {
        super.setUp()
        logger = SLAMLogger()
    }

    override func tearDown() {
        if logger.isRecording {
            logger.stopRecording()
        }
        logger = nil
        super.tearDown()
    }

    func testARViewContainerHasCorrectLogger() {
        let container = ARViewContainer(logger: logger)
        XCTAssertTrue(container.logger === logger)
    }
}
