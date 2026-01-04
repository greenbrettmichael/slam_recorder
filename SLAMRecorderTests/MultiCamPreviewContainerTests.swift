import AVFoundation
@testable import SLAMRecorder
import SwiftUI
import ViewInspector
import XCTest

final class MultiCamPreviewContainerTests: XCTestCase {
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

    func testMultiCamPreviewContainerHasCorrectLogger() {
        let container = MultiCamPreviewContainer(logger: logger)
        XCTAssertTrue(container.logger === logger)
    }

    func testMultiCamPreviewContainerReturnsEmptyLayersInitially() {
        let container = MultiCamPreviewContainer(logger: logger)
        let layers = container.logger.multiCamPreviewLayers()
        XCTAssertTrue(layers.isEmpty)
    }
}
