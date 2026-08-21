//
//  Elyra_VitaUITestsLaunchTests.swift
//  Elyra_VitaUITests
//
//  Created by Pascal Smigielski on 14.08.26.
//

import XCTest

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
}
