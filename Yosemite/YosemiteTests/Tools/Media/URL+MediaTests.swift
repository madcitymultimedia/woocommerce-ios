import MobileCoreServices
import XCTest
import UniformTypeIdentifiers
@testable import Yosemite

final class URL_MediaTests: XCTestCase {

    // MARK: tests for `mimeTypeForPathExtension`

    func testMimeTypeForJPEGFileURL() throws {
        try XCTSkipIf(testingOnRosetta())
        let url = URL(string: "/test/product.jpeg")
        let expectedMimeType = "image/jpeg"
        XCTAssertEqual(url?.mimeTypeForPathExtension, expectedMimeType)
    }

    func testMimeTypeForJPGFileURL() throws {
        try XCTSkipIf(testingOnRosetta())
        let url = URL(string: "/test/product.jpg")
        let expectedMimeType = "image/jpeg"
        XCTAssertEqual(url?.mimeTypeForPathExtension, expectedMimeType)
    }

    func testMimeTypeForGIFFileURL() throws {
        try XCTSkipIf(testingOnRosetta())
        let url = URL(string: "/test/product.gif")
        let expectedMimeType = "image/gif"
        XCTAssertEqual(url?.mimeTypeForPathExtension, expectedMimeType)
    }

    func testMimeTypeForPNGFileURL() throws {
        try XCTSkipIf(testingOnRosetta())
        let url = URL(string: "/test/product.png")
        let expectedMimeType = "image/png"
        XCTAssertEqual(url?.mimeTypeForPathExtension, expectedMimeType)
    }

    // MARK: tests for `fileExtensionForUTType`

    func testFileExtensionForJPEGType() {
        let expectedFileExtension = "jpeg"
        XCTAssertEqual(URL.fileExtensionForUTType(UTType.jpeg.identifier), expectedFileExtension)
    }

    func testFileExtensionForGIFType() {
        let expectedFileExtension = "gif"
        XCTAssertEqual(URL.fileExtensionForUTType(UTType.gif.identifier), expectedFileExtension)
    }

    func testFileExtensionForPNGType() {
        let expectedFileExtension = "png"
        XCTAssertEqual(URL.fileExtensionForUTType(UTType.png.identifier), expectedFileExtension)
    }
}
