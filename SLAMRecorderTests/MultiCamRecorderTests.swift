import XCTest
@testable import SLAMRecorder

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
}
