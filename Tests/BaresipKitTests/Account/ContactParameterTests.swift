import XCTest
@testable import BaresipKit

final class ContactParameterTests: XCTestCase {
    func testEncodingPreservesSeparators() throws {
        let params = [
            BaresipContactParameter("app-id", "com.example.app"),
            BaresipContactParameter("pn-type", "apple"),
            BaresipContactParameter("pn-tok", "0123abcd:remote&ffff0000:voip"),
            BaresipContactParameter("pn-silent", "1"),
            BaresipContactParameter("pn-timeout", "0"),
        ]
        let encoded = try BaresipEngine.encodeContactParameters(params)
        let expected = "app-id=com.example.app;pn-type=apple;pn-tok=0123abcd:remote&ffff0000:voip"
            + ";pn-silent=1;pn-timeout=0"
        XCTAssertEqual(encoded, expected)
    }

    func testRejectsSeparatorInsideValue() {
        XCTAssertThrowsError(try BaresipEngine.encodeContactParameters([BaresipContactParameter("pn-tok", "a;b")]))
        XCTAssertThrowsError(try BaresipEngine.encodeContactParameters([BaresipContactParameter("pn tok", "a")]))
        XCTAssertThrowsError(try BaresipEngine.encodeContactParameters([BaresipContactParameter("pn-tok", "a b")]))
    }

    func testEmptyIsAllowed() throws {
        XCTAssertEqual(try BaresipEngine.encodeContactParameters([]), "")
    }
}
