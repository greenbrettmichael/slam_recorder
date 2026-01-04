@testable import SLAMRecorder
import XCTest

@available(iOS 13.0, *)
final class MultiCamRecorderTests: XCTestCase {
    func testOutputURLsAreUniquePerCamera() {
        let dir = FileManager.default.temporaryDirectory
        let cameras: Set<CameraID> = [.backWide, .front, .backUltraWide]
        let urls = MultiCamRecorder.makeOutputURLs(for: cameras, in: dir)
        XCTAssertEqual(urls.count, cameras.count)
        XCTAssertTrue(urls.values.allSatisfy { $0.path.hasSuffix(".mov") })
        XCTAssertEqual(urls[.backWide]?.lastPathComponent, "camera_back_wide.mov")
        XCTAssertEqual(urls[.front]?.lastPathComponent, "camera_front.mov")
    }

    func testMakeOutputURLsStableFileNames() {
        let dir = URL(fileURLWithPath: "/tmp")
        let urls = MultiCamRecorder.makeOutputURLs(for: [.backTelephoto], in: dir)
        XCTAssertEqual(urls[.backTelephoto]?.path, "/tmp/camera_back_tele.mov")
    }

    func testLimitedCameraSetRespectsPriority() {
        let requested: Set<CameraID> = [.backWide, .front, .backUltraWide, .backTelephoto]
        let limited = MultiCamRecorder.limitedCameraSet(from: requested)
        XCTAssertEqual(limited.count, 2)
        XCTAssertTrue(limited.contains(.backWide))
        XCTAssertTrue(limited.contains(.front))
    }

    func testLimitedCameraSetWithLessThanMax() {
        let requested: Set<CameraID> = [.backWide]
        let limited = MultiCamRecorder.limitedCameraSet(from: requested)
        XCTAssertEqual(limited.count, 1)
        XCTAssertTrue(limited.contains(.backWide))
    }

    func testLimitedCameraSetEmptyInput() {
        let requested: Set<CameraID> = []
        let limited = MultiCamRecorder.limitedCameraSet(from: requested)
        XCTAssertTrue(limited.isEmpty)
    }

    func testLimitedCameraSetFallbackPriority() {
        let requested: Set<CameraID> = [.backUltraWide, .backTelephoto]
        let limited = MultiCamRecorder.limitedCameraSet(from: requested)
        XCTAssertEqual(limited.count, 2)
        XCTAssertTrue(limited.contains(.backUltraWide))
        XCTAssertTrue(limited.contains(.backTelephoto))
    }

    func testCameraIDFileNameComponents() {
        XCTAssertEqual(CameraID.backWide.fileNameComponent, "back_wide")
        XCTAssertEqual(CameraID.backUltraWide.fileNameComponent, "back_ultrawide")
        XCTAssertEqual(CameraID.backTelephoto.fileNameComponent, "back_tele")
        XCTAssertEqual(CameraID.front.fileNameComponent, "front")
    }

    func testCameraIDDisplayNames() {
        XCTAssertEqual(CameraID.backWide.displayName, "Back Wide")
        XCTAssertEqual(CameraID.backUltraWide.displayName, "Back Ultra-Wide")
        XCTAssertEqual(CameraID.backTelephoto.displayName, "Back Telephoto")
        XCTAssertEqual(CameraID.front.displayName, "Front")
    }

    func testCameraIDPositions() {
        XCTAssertEqual(CameraID.backWide.position, .back)
        XCTAssertEqual(CameraID.backUltraWide.position, .back)
        XCTAssertEqual(CameraID.backTelephoto.position, .back)
        XCTAssertEqual(CameraID.front.position, .front)
    }

    func testCameraIDResolveDevice() {
        // Test that resolveDevice returns a device (may be nil on simulator)
        // This at least tests the method is callable
        _ = CameraID.backWide.resolveDevice()
        _ = CameraID.front.resolveDevice()
        _ = CameraID.backUltraWide.resolveDevice()
        _ = CameraID.backTelephoto.resolveDevice()
    }

    func testCameraIDAllCases() {
        let allCases = CameraID.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.backWide))
        XCTAssertTrue(allCases.contains(.backUltraWide))
        XCTAssertTrue(allCases.contains(.backTelephoto))
        XCTAssertTrue(allCases.contains(.front))
    }
}
