// SafePing — SafePingUITests.swift
// UI tests for the SafePing iOS app using XCTest.
//
// Setup: In Xcode add a "UI Testing Bundle" target named "SafePingUITests",
// then add this file to that target.
//
// Test coverage:
//   1. Login screen renders key elements
//   2. Register tab is reachable from the login screen
//   3. Login with wrong credentials shows an error
//
// [Procedural] Tests follow Arrange → Act → Assert order.
// [OOP] XCTestCase subclass groups related tests behind a shared setUp/tearDown lifecycle.

import XCTest

final class SafePingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Login screen

    // Verifies that the login screen shows the brand name and input fields on launch.
    func testLoginScreenElements() throws {
        let usernameField = app.textFields["Username"]
        let passwordField = app.secureTextFields["Password"]
        let signInButton  = app.buttons["Sign In"]

        XCTAssertTrue(usernameField.waitForExistence(timeout: 5), "Username field should be visible")
        XCTAssertTrue(passwordField.exists, "Password field should be visible")
        XCTAssertTrue(signInButton.exists,  "Sign In button should be visible")
    }

    // Verifies that tapping "Register" navigates to the registration screen.
    func testNavigateToRegister() throws {
        let registerButton = app.buttons["Register"]
        XCTAssertTrue(registerButton.waitForExistence(timeout: 5))
        registerButton.tap()

        let createAccountButton = app.buttons["Create Account"]
        XCTAssertTrue(createAccountButton.waitForExistence(timeout: 5),
                      "Create Account button should appear on the register screen")
    }

    // Verifies that submitting wrong credentials shows an error message.
    func testLoginWithBadCredentialsShowsError() throws {
        let usernameField = app.textFields["Username"]
        let passwordField = app.secureTextFields["Password"]
        let signInButton  = app.buttons["Sign In"]

        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText("nonexistent_user")

        passwordField.tap()
        passwordField.typeText("WrongPass1")

        signInButton.tap()

        // The error label should appear within a reasonable timeout
        let errorLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Invalid'")).firstMatch
        XCTAssertTrue(errorLabel.waitForExistence(timeout: 8),
                      "An error message containing 'Invalid' should appear for bad credentials")
    }
}
