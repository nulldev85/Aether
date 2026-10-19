import XCTest

/// UI tests run against the app in mock mode via launch arguments. No network
/// access and no real credentials are used.
final class IPTVRadioUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(scenario: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMock", "-UITestScenario=\(scenario)"] + extraArguments
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertBottomPlayerControls(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let card = app.descendants(matching: .any).matching(identifier: "nowplaying.controls").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertEqual(card.frame.midX, app.frame.midX, accuracy: 2, file: file, line: line)
        XCTAssertLessThanOrEqual(card.frame.height, 142, "The old control card was 176 points tall", file: file, line: line)
        let bottomGap = app.frame.maxY - card.frame.maxY
        XCTAssertGreaterThanOrEqual(bottomGap, 12, "Respect the bottom safe area", file: file, line: line)
        XCTAssertLessThanOrEqual(bottomGap, 90, "Controls belong at the bottom, not under the track in mid-screen", file: file, line: line)
        for name in ["nowplaying.previous", "nowplaying.stop", "nowplaying.next"] {
            let button = app.buttons[name]
            XCTAssertTrue(button.isHittable, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, file: file, line: line)
        }
        XCTAssertEqual(app.buttons["nowplaying.stop"].frame.midX, app.frame.midX, accuracy: 2, file: file, line: line)
        XCTAssertTrue(app.buttons["nowplaying.sleepTimer"].isHittable, file: file, line: line)
        XCTAssertTrue(app.buttons["nowplaying.retry"].isHittable, file: file, line: line)
        XCTAssertTrue(app.buttons["nowplaying.close"].isHittable, file: file, line: line)
    }

    func testLoginFlowShowsFormAndAuthorizesMockCredentials() throws {
        let app = launch(scenario: "UITestLogin")

        let serverField = app.textFields["login.server"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 10))

        serverField.tap()
        serverField.typeText("https://demo.example.net:8080")
        let usernameField = app.textFields["login.username"]
        usernameField.tap()
        usernameField.typeText("uitest-user")
        let passwordField = app.secureTextFields["login.password"]
        passwordField.tap()
        passwordField.typeText("uitest-pass\n")

        // Return key submits via onSubmit; fall back to the button if needed.
        if !app.buttons["Radio"].waitForExistence(timeout: 10),
           app.buttons["login.submit"].exists {
            app.swipeUp()
            app.buttons["login.submit"].tap()
        }
        let radioTab = app.buttons["Radio"]
        if !radioTab.waitForExistence(timeout: 10) {
            XCTFail("Radio tab not found after sign-in. Hierarchy:\n\(app.debugDescription)")
        }
    }

    func testRadioTabListsStationsAndSeeAll() throws {
        let app = launch(scenario: "UITestBrowse")

        // SiriusXM keeps its own tab beside the listener's Radio stations.
        app.buttons["SXM"].tap()
        XCTAssertTrue(app.staticTexts["SiriusXM Hits 1"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["SiriusXM Octane"].exists)
        capture(app, name: "Shell — SiriusXM")

        // Radio only: there is no TV/video browsing tab.
        XCTAssertFalse(app.buttons["Browse"].exists, "TV browsing must not exist in a radio-only app")

        app.buttons["radio.seeAll"].tap()
        XCTAssertTrue(app.navigationBars["SiriusXM Stations"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["station.row.SiriusXM Hits 1"].waitForExistence(timeout: 8))
    }

    func testSearchFindsStationsByGenreAndName() throws {
        let app = launch(scenario: "UITestSearch")

        app.buttons["Search"].tap()
        let searchField = app.textFields["search.field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 8))
        searchField.tap()
        searchField.typeText("Jazz")

        XCTAssertTrue(app.staticTexts["Jazz Cafe Radio"].waitForExistence(timeout: 8))
        capture(app, name: "Shell — Search")
    }

    func testManualRadioStationCanBeAddedPlayedAndRemoved() throws {
        let app = launch(scenario: "UITestBrowse")
        XCTAssertTrue(app.staticTexts["Your Radio stations"].waitForExistence(timeout: 8))
        capture(app, name: "Shell — Radio")

        app.buttons["manual.addEmpty"].tap()
        let name = app.textFields["manual.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        name.tap()
        name.typeText("My Test Radio")
        let url = app.textFields["manual.url"]
        url.tap()
        url.typeText("https://radio.example.org/live.mp3")
        app.buttons["manual.save"].tap()

        let row = app.buttons["station.row.My Test Radio"]
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForExistence(timeout: 8))

        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["Your Radio stations"].waitForExistence(timeout: 8))
    }

    func testAetherDialOpensFromRadioWithoutChangingTabs() throws {
        let app = launch(scenario: "UITestBrowse")
        app.buttons["manual.dialEmpty"].tap()
        XCTAssertTrue(app.navigationBars["Aether Dial"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["dial.place"].exists)
        XCTAssertTrue(app.buttons["dial.search"].exists)
        XCTAssertTrue(app.buttons["Listen to Dial Jazz"].waitForExistence(timeout: 8))
        app.swipeUp()
        app.buttons["Listen to Dial Jazz"].tap()
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForExistence(timeout: 8))
        app.buttons["Add Dial Jazz to Radio"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["station.row.Dial Jazz"].waitForExistence(timeout: 8))
    }

    func testFavoritesToggleAndLibraryListing() throws {
        let app = launch(scenario: "UITestFavorites")

        // Two stations were favorited by the mock scenario.
        app.buttons["Favorites"].tap()
        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["SiriusXM Hits 1"].waitForExistence(timeout: 8))

        capture(app, name: "Shell — Favorites")

        // Favorites must be playable from the Favorites tab.
        app.buttons["station.row.SiriusXM Hits 1"].firstMatch.tap()
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForExistence(timeout: 8),
                      "Tapping a favorite must start playback")
    }

    func testFavoritesReorderMovesExactlyOnePlace() throws {
        let app = launch(scenario: "UITestFavorites")
        app.buttons["Favorites"].tap()
        app.buttons["favorites.reorder"].tap()

        let hits = app.buttons["station.row.SiriusXM Hits 1"].firstMatch
        let octane = app.buttons["station.row.SiriusXM Octane"].firstMatch
        XCTAssertTrue(hits.waitForExistence(timeout: 8))
        XCTAssertTrue(octane.exists)
        let hitsWasBelow = hits.frame.minY > octane.frame.minY
        let lowerName = hitsWasBelow ? "SiriusXM Hits 1" : "SiriusXM Octane"
        app.buttons["reorder.up.\(lowerName)"].tap()
        if hitsWasBelow {
            XCTAssertLessThan(hits.frame.minY, octane.frame.minY)
        } else {
            XCTAssertLessThan(octane.frame.minY, hits.frame.minY)
        }
    }

    func testNowPlayingScreenShowsStateAndControls() throws {
        let app = launch(scenario: "UITestNowPlaying")

        // Mini player visible with the playing station.
        XCTAssertTrue(app.staticTexts["SiriusXM Hits 1"].waitForExistence(timeout: 8))
        let toggle = app.buttons["miniplayer.toggle"]
        if !toggle.waitForExistence(timeout: 8) {
            XCTFail("Mini player not visible. Hierarchy:\n\(app.debugDescription)")
        }

        // Tab navigation must remain usable while a station is playing.
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.category.account"].waitForExistence(timeout: 8),
                      "Tab bar must remain reachable during playback")
        capture(app, name: "Lineup style — Settings with vinyl mini player")
        app.buttons["SXM"].tap()
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForExistence(timeout: 8))

        let miniPlayer = app.buttons["miniplayer.open"].firstMatch
        miniPlayer.tap()
        XCTAssertTrue(app.buttons["nowplaying.close"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "nowplaying.vinyl").firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["nowplaying.stop"].exists)
        XCTAssertTrue(app.buttons["nowplaying.sleepTimer"].exists)
        assertBottomPlayerControls(app)
        let vinyl = app.descendants(matching: .any).matching(identifier: "nowplaying.vinyl").firstMatch
        let status = app.descendants(matching: .any).matching(identifier: "nowplaying.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertEqual(vinyl.frame.midX, app.frame.midX, accuracy: 2)
        XCTAssertEqual(vinyl.frame.width, vinyl.frame.height, accuracy: 1)
        let stageMidY = (app.buttons["nowplaying.close"].frame.maxY + status.frame.minY) / 2
        XCTAssertEqual(vinyl.frame.midY, stageMidY, accuracy: 3,
                       "Center the record in the free space between the header and track details")
        capture(app, name: "Lineup style — Now Playing with preserved vinyl")

        app.buttons["nowplaying.close"].tap()
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForExistence(timeout: 8),
                      "Closing the restyled player must retain playback and the vinyl mini player")
        app.buttons["miniplayer.open"].firstMatch.tap()
        XCTAssertTrue(app.buttons["nowplaying.close"].waitForExistence(timeout: 8))

        // Switching stations repeatedly works without leaving the player.
        app.buttons["nowplaying.next"].tap()
        XCTAssertTrue(app.buttons["nowplaying.stop"].waitForExistence(timeout: 8))

        // Swipe the sheet down; playback continues in the mini player.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        from.press(forDuration: 0.1, thenDragTo: to)
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForExistence(timeout: 8))

        // Explicit Stop clears the mini player entirely so the full UI (and
        // tab bar) is always recoverable without restarting the app.
        app.buttons["miniplayer.stop"].tap()
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForNonExistence(timeout: 8),
                      "Stopping must clear the mini player")
        XCTAssertTrue(app.buttons["Radio"].waitForExistence(timeout: 8))
    }

    func testBottomPlayerControlsStayReachableWhenRecordDetailsNeedToScroll() throws {
        let app = launch(scenario: "UITestNowPlaying")
        defer { XCUIDevice.shared.orientation = .portrait }
        let mini = app.buttons["miniplayer.open"].firstMatch
        XCTAssertTrue(mini.waitForExistence(timeout: 8))
        mini.tap()
        XCTAssertTrue(app.buttons["nowplaying.close"].waitForExistence(timeout: 8))
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 8), .completed)
        assertBottomPlayerControls(app)
        let scroller = app.scrollViews.firstMatch
        XCTAssertTrue(scroller.waitForExistence(timeout: 8), "Short layouts must allow the record and details to scroll")
        let card = app.descendants(matching: .any).matching(identifier: "nowplaying.controls").firstMatch
        let before = card.frame
        scroller.swipeUp()
        XCTAssertEqual(card.frame.minY, before.minY, accuracy: 2, "Scrolling details must not move transport controls")
        assertBottomPlayerControls(app)
        capture(app, name: "Bottom controls — compact-height player")
        app.buttons["nowplaying.close"].tap()
        XCTAssertTrue(mini.waitForExistence(timeout: 8), "Closing still retains playback")
    }

    func testLiquidGlassSettingKeepsNavigationAndMiniPlayer() throws {
        let app = launch(scenario: "UITestNowPlaying")
        app.buttons["Settings"].tap()
        app.buttons["settings.category.app"].tap()

        let liquidGlassSwitch = app.descendants(matching: .any)
            .matching(identifier: "settings.liquidGlass")
            .firstMatch
        XCTAssertTrue(liquidGlassSwitch.waitForExistence(timeout: 8))
        if !app.buttons["tab.favorites"].exists {
            liquidGlassSwitch.tap()
        }

        let flatFavorites = app.buttons["tab.favorites"]
        if !flatFavorites.waitForExistence(timeout: 8) {
            XCTFail("Lineup floating navigation did not appear after switching modes. Hierarchy:\n\(app.debugDescription)")
        }
        XCTAssertTrue(app.buttons["miniplayer.open"].exists)
        flatFavorites.tap()
        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 8))
        app.buttons["tab.settings"].tap()
        app.buttons["settings.category.app"].tap()
        liquidGlassSwitch.tap()

        XCTAssertTrue(app.buttons["SXM"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["miniplayer.open"].exists)
    }

    func testSettingsCategoriesExposeExistingControls() throws {
        let app = launch(scenario: "UITestBrowse")
        app.buttons["Settings"].tap()

        XCTAssertTrue(app.buttons["settings.signOut"].waitForExistence(timeout: 8))
        capture(app, name: "Rounded type — Settings Account")
        app.buttons["settings.category.stations"].tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.siriusOnly").firstMatch.waitForExistence(timeout: 8))
        capture(app, name: "Rounded type — Settings Stations")
        app.buttons["settings.category.playback"].tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.cellular").firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.cellularBuffer").firstMatch.waitForExistence(timeout: 8))
        capture(app, name: "Rounded type — Settings Playback")
        let cellular = app.switches["settings.cellular"]
        XCTAssertTrue(cellular.exists, "The styled wrapper must still expose a native switch")
        let original = try XCTUnwrap(cellular.value as? String)
        cellular.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", original), object: cellular)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
        let updated = try XCTUnwrap(cellular.value as? String)
        app.buttons["settings.category.app"].tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.liquidGlass").firstMatch.waitForExistence(timeout: 8))
        capture(app, name: "Rounded type — Settings App")
        app.buttons["settings.category.playback"].tap()
        XCTAssertTrue(cellular.waitForExistence(timeout: 8))
        XCTAssertEqual(cellular.value as? String, updated, "The styled switch must keep its real Settings binding")
        cellular.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", original), object: cellular)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 3), .completed)
    }

    func testLineupFloatingControlsLeaveStationNavigationAndStopReachable() throws {
        let app = launch(scenario: "UITestNowPlaying")
        let first = app.buttons["tab.radio"]
        let last = app.buttons["tab.settings"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        XCTAssertTrue(last.isHittable)
        let mini = app.buttons["miniplayer.open"].firstMatch
        XCTAssertTrue(mini.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(mini.frame.maxY, first.frame.minY,
                                 "Vinyl mini player must not cover the floating navigation")
        XCTAssertGreaterThanOrEqual(first.frame.minX, app.frame.minX + 20)
        XCTAssertLessThanOrEqual(last.frame.maxX, app.frame.maxX - 20)
        app.buttons["tab.favorites"].tap()
        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["miniplayer.stop"].isHittable)
        capture(app, name: "Lineup style — compact controls and station clearance")
        app.buttons["miniplayer.stop"].tap()
        XCTAssertTrue(mini.waitForNonExistence(timeout: 8))
        XCTAssertTrue(last.isHittable)
    }
}
