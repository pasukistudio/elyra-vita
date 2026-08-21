//
//  Elyra_VitaUITestsLaunchTests.swift
//  Elyra_VitaUITests
//
//  Created by Pascal Smigielski on 14.08.26.
//

import XCTest

// MARK: - Elyra_VitaUITestsLaunchTests

/// Prüft den isolierten App-Start und erzeugt einen dauerhaft sichtbaren Screenshot.
final class Elyra_VitaUITestsLaunchTests: XCTestCase {
    // MARK: - Test-Konfiguration

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        // Der Test soll beim ersten Fehler abbrechen.
        continueAfterFailure = false
    }

    // MARK: - Start-Screenshot

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        // Der UI-Test prüft den App-Start isoliert von iCloud/CloudKit.
        app.launchArguments.append("--disable-cloudkit")
        app.launchArguments.append("--disable-healthkit")
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Toolbar-Menüs

    func testOverviewToolbarMenuContainsOverviewActions() {
        let app = launchedApp()

        app.buttons["toolbar.addMenu"].tap()

        XCTAssertTrue(app.buttons["toolbar.action.meal"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["toolbar.action.water"].exists)
        XCTAssertTrue(app.buttons["toolbar.action.weight"].exists)
        XCTAssertFalse(app.buttons["toolbar.action.breakfast"].exists)
    }

    func testNutritionToolbarMenuContainsNutritionActions() {
        let app = launchedApp()
        let nutritionTab = app.tabBars.buttons["Ernährung"]

        XCTAssertTrue(nutritionTab.waitForExistence(timeout: 2))
        nutritionTab.tap()
        app.buttons["toolbar.addMenu"].tap()

        XCTAssertTrue(app.buttons["toolbar.action.breakfast"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["toolbar.action.lunch"].exists)
        XCTAssertTrue(app.buttons["toolbar.action.dinner"].exists)
        XCTAssertTrue(app.buttons["toolbar.action.snack"].exists)
        XCTAssertTrue(app.buttons["toolbar.action.water"].exists)
        XCTAssertFalse(app.buttons["toolbar.action.weight"].exists)
    }

    // MARK: - Test-Helfer

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--disable-cloudkit")
        app.launchArguments.append("--disable-healthkit")
        app.launch()
        return app
    }
}
