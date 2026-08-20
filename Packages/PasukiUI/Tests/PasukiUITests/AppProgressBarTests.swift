import XCTest
@testable import PasukiUI

final class AppProgressBarTests: XCTestCase {

    // MARK: - Fortschrittsgrenzen

    /// Die Komponente soll Werte außerhalb des gültigen Bereichs sicher behandeln.
    func testProgressBarAcceptsBoundaryValues() {
        let empty = AppProgressBar(progress: 0, color: .blue)
        let full = AppProgressBar(progress: 1, color: .blue)

        XCTAssertEqual(empty.progress, 0)
        XCTAssertEqual(full.progress, 1)
    }

    /// Negative und übervolle Werte werden erst beim Rendern begrenzt.
    func testProgressBarPreservesInputForReusableConfiguration() {
        let belowMinimum = AppProgressBar(progress: -0.5, color: .blue)
        let aboveMaximum = AppProgressBar(progress: 1.5, color: .blue)

        XCTAssertEqual(belowMinimum.progress, -0.5)
        XCTAssertEqual(aboveMaximum.progress, 1.5)
    }
}
