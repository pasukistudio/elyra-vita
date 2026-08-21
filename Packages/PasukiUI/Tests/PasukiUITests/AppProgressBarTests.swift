import XCTest
@testable import PasukiUI

// MARK: - AppProgressBarTests

/// Verhaltenstests für die wiederverwendbare Fortschrittsanzeige.
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

// MARK: - PasukiAccentColorSelectionTests

final class PasukiAccentColorSelectionTests: XCTestCase {

    // MARK: - Testzugriff

    func testPresetDoesNotRequireProAccess() {
        let selection = PasukiAccentColorSelection.preset(.blue)

        XCTAssertNil(selection.requiredProFeature)
        XCTAssertTrue(selection.isAvailable(for: TestProAccess(isUnlocked: false)))
    }

    func testCustomColorUsesSharedProFeature() {
        let selection = PasukiAccentColorSelection.custom(hex: "#007AFF")

        XCTAssertEqual(
            selection.requiredProFeature,
            .customAccentColor
        )
        XCTAssertFalse(selection.isAvailable(for: TestProAccess(isUnlocked: false)))
        XCTAssertTrue(selection.isAvailable(for: TestProAccess(isUnlocked: true)))
    }
}

// MARK: - PasukiSharedSettingsTests

final class PasukiSharedSettingsTests: XCTestCase {

    func testAppearanceProvidesStablePresentationValues() {
        XCTAssertEqual(PasukiAppearance.system.rawValue, "system")
        XCTAssertNil(PasukiAppearance.system.colorScheme)
        XCTAssertEqual(PasukiAppearance.dark.colorScheme, .dark)
    }

    func testColorPresetValuesRemainStable() {
        XCTAssertEqual(PasukiColorPreset.blue.rawValue, "blue")
        XCTAssertEqual(PasukiColorPreset.blue.hex, "#007AFF")
        XCTAssertEqual(PasukiColorPreset.allCases.count, 10)
    }
}

// MARK: - TestProAccess

private struct TestProAccess: PasukiProAccess {
    let isUnlocked: Bool

    func hasAccess(to feature: PasukiProFeature) -> Bool {
        isUnlocked
    }
}
