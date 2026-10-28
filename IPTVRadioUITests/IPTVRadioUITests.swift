import XCTest

/// UI tests run against the app in mock mode via launch arguments. No network
/// access and no real credentials are used.
final class IPTVRadioUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 {
            // Mock scenarios contain no real provider credentials. Keep the
            // failing native tree in the job log, not only a binary xcresult.
            print("Failed UI hierarchy:\n\(XCUIApplication().debugDescription)")
        }
    }

    private func launch(scenario: String, extraArguments: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMock", "-UITestScenario=\(scenario)"] + extraArguments
        app.launch()
        let portrait = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.height > app.frame.width
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [portrait], timeout: 8), .completed,
                       "Every scenario must begin in portrait, including after the rotation regression")
        return app
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openSettingsCategory(_ name: String, in app: XCUIApplication) {
        let link = app.buttons["settings.category.\(name)"]
        if !link.exists {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: 8))
            back.tap()
        }
        XCTAssertTrue(link.waitForExistence(timeout: 8))
        link.tap()
    }

    private func settingSwitch(_ identifier: String, in app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        // Resolve one native switch, rather than an Any/firstMatch wrapper
        // retained across a NavigationStack pop and push.
        let control = app.switches.matching(identifier: identifier).element
        XCTAssertTrue(control.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertTrue(control.isHittable, file: file, line: line)
        return control
    }

    private func settingValue(_ identifier: String, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let control = settingSwitch(identifier, in: app, file: file, line: line)
        let value = try XCTUnwrap(control.value as? String,
                                 "Read the native switch value", file: file, line: line)
        XCTAssertTrue(value == "0" || value == "1", "Unexpected switch value: \(value)", file: file, line: line)
        return value
    }

    private func toggleSetting(_ identifier: String, to expected: String, in app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) throws {
        let control = settingSwitch(identifier, in: app, file: file, line: line)
        XCTAssertNotEqual(try settingValue(identifier, in: app, file: file, line: line), expected,
                          "The test must exercise an actual state change", file: file, line: line)
        control.tap()
        // tap() waits for the native event and app idleness. These bindings
        // change synchronously: read a fresh native query immediately, without
        // a timer-based predicate competing with slow accessibility snapshots.
        XCTAssertEqual(try settingValue(identifier, in: app, file: file, line: line), expected,
                       "The completed tap must update the real setting", file: file, line: line)
    }

    private func nowPlayingScreen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let screens = app.descendants(matching: .any).matching(identifier: "nowplaying.screen")
        XCTAssertTrue(screens.firstMatch.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertEqual(screens.count, 1, "Use the presented player, not the persistent shelf behind it", file: file, line: line)
        return screens.firstMatch
    }

    private func assertBottomPlayerControls(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let player = nowPlayingScreen(app, file: file, line: line)
        let card = player.descendants(matching: .any).matching(identifier: "nowplaying.controls").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertEqual(card.frame.midX, app.frame.midX, accuracy: 2, file: file, line: line)
        XCTAssertLessThanOrEqual(card.frame.height, 142, "The old control card was 176 points tall", file: file, line: line)
        let bottomGap = app.frame.maxY - card.frame.maxY
        XCTAssertGreaterThanOrEqual(bottomGap, 12, "Respect the bottom safe area", file: file, line: line)
        XCTAssertLessThanOrEqual(bottomGap, 90, "Controls belong at the bottom, not under the track in mid-screen", file: file, line: line)
        for name in ["nowplaying.previous", "nowplaying.stop", "nowplaying.next"] {
            let button = player.buttons[name]
            XCTAssertTrue(button.isHittable, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, file: file, line: line)
        }
        XCTAssertEqual(player.buttons["nowplaying.stop"].frame.midX, app.frame.midX, accuracy: 2, file: file, line: line)
        XCTAssertTrue(player.buttons["nowplaying.sleepTimer"].isHittable, file: file, line: line)
        XCTAssertTrue(player.buttons["nowplaying.retry"].isHittable, file: file, line: line)
        XCTAssertTrue(player.buttons["nowplaying.close"].isHittable, file: file, line: line)
    }

    func testLoginFlowShowsFormAndAuthorizesMockCredentials() throws {
        let app = launch(scenario: "UITestLogin")

        let serverField = app.textFields["login.server"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 10))
        capture(app, name: "Workspace — Sign in")

        serverField.tap()
        serverField.typeText("https://demo.example.net:8080")
        let usernameField = app.textFields["login.username"]
        usernameField.tap()
        usernameField.typeText("uitest-user")
        let passwordField = app.secureTextFields["login.password"]
        if !passwordField.isHittable { app.swipeUp() }
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
        XCTAssertTrue(app.buttons["station.row.SiriusXM Hits 1"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["station.row.SiriusXM Octane"].exists)
        capture(app, name: "Workspace — SiriusXM")

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

        XCTAssertTrue(app.buttons["station.row.Jazz Cafe Radio"].waitForExistence(timeout: 8))
        capture(app, name: "Workspace — Search")
    }

    func testGenreShortcutsUseRealStationSearchAndClearReturnsToDiscovery() throws {
        let app = launch(scenario: "UITestSearch")
        app.buttons["Search"].tap()
        let shortcut = app.buttons["search.suggestion.jazz"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 8))
        capture(app, name: "Workspace — Search discovery")
        shortcut.tap()
        let field = app.textFields["search.field"]
        XCTAssertEqual(field.value as? String, "Jazz")
        XCTAssertTrue(app.buttons["station.row.Jazz Cafe Radio"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["station.row.SiriusXM Hits 1"].exists)
        app.buttons["Clear search"].tap()
        XCTAssertTrue(shortcut.waitForExistence(timeout: 8))
        let clearedValue = try XCTUnwrap(field.value as? String)
        XCTAssertTrue(clearedValue.isEmpty || clearedValue == field.placeholderValue,
                      "An empty native field may expose its placeholder, but must not retain the query")
        app.buttons["Radio"].tap()
        XCTAssertTrue(app.buttons["manual.addEmpty"].waitForExistence(timeout: 8))
    }

    func testManualRadioStationCanBeAddedPlayedAndRemoved() throws {
        let app = launch(scenario: "UITestBrowse")
        XCTAssertTrue(app.staticTexts["Your Radio stations"].waitForExistence(timeout: 8))
        capture(app, name: "Workspace — Radio")

        app.buttons["manual.addEmpty"].tap()
        let name = app.textFields["manual.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        capture(app, name: "Workspace — Station editor")
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

        app.buttons["manual.manage.My Test Radio"].tap()
        app.buttons["Delete Station"].tap()
        XCTAssertTrue(app.staticTexts["Your Radio stations"].waitForExistence(timeout: 8))
    }

    func testAetherDialOpensFromRadioWithoutChangingTabs() throws {
        let app = launch(scenario: "UITestBrowse")
        app.buttons["manual.dialEmpty"].tap()
        XCTAssertTrue(app.navigationBars["Aether Dial"].waitForExistence(timeout: 8))
        let filters = app.buttons["dial.filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 8))
        XCTAssertEqual(filters.value as? String, "Collapsed")
        filters.tap()
        let place = app.textFields["dial.place"]
        XCTAssertTrue(place.waitForExistence(timeout: 8))
        XCTAssertEqual(filters.value as? String, "Expanded")
        XCTAssertTrue(place.isHittable)
        place.tap()
        place.typeText("California")
        filters.tap()
        XCTAssertTrue(place.waitForNonExistence(timeout: 8))
        XCTAssertEqual(filters.value as? String, "Collapsed")
        filters.tap()
        XCTAssertTrue(place.waitForExistence(timeout: 8))
        XCTAssertEqual(place.value as? String, "California", "Collapsing filters must preserve the listener's input")
        XCTAssertTrue(app.buttons["dial.search"].exists)
        capture(app, name: "Workspace — Dial")
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
        XCTAssertTrue(app.staticTexts["page.title.Favorites"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["station.row.SiriusXM Hits 1"].waitForExistence(timeout: 8))

        capture(app, name: "Workspace — Favorites")

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
        let hitsWasBelow = hits.frame.minY > octane.frame.minY + 2
            || (abs(hits.frame.minY - octane.frame.minY) <= 2 && hits.frame.minX > octane.frame.minX)
        let lowerName = hitsWasBelow ? "SiriusXM Hits 1" : "SiriusXM Octane"
        app.buttons["reorder.up.\(lowerName)"].tap()
        if hitsWasBelow {
            XCTAssertTrue(hits.frame.minY < octane.frame.minY - 2
                || (abs(hits.frame.minY - octane.frame.minY) <= 2 && hits.frame.minX < octane.frame.minX))
        } else {
            XCTAssertTrue(octane.frame.minY < hits.frame.minY - 2
                || (abs(hits.frame.minY - octane.frame.minY) <= 2 && octane.frame.minX < hits.frame.minX))
        }
    }

    func testPlayerArrowsFollowTheArrangedFavoritesListAndWrap() throws {
        let app = launch(scenario: "UITestFavorites")
        // Three favorites distinguish Previous from Next, and leave other
        // provider channels outside this listening queue.
        app.buttons["tab.sxm"].tap()
        let add = app.buttons["station.favorite.SiriusXM PopRocks"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.tap()
        app.buttons["tab.favorites"].tap()
        app.buttons["favorites.reorder"].tap()
        app.buttons["reorder.up.SiriusXM Hits 1"].tap()
        app.buttons["favorites.reorder"].tap()

        // The visible order is now PopRocks, Hits 1, Octane.
        let pop = app.buttons["station.row.SiriusXM PopRocks"]
        let hits = app.buttons["station.row.SiriusXM Hits 1"]
        let octane = app.buttons["station.row.SiriusXM Octane"]
        XCTAssertTrue(hits.waitForExistence(timeout: 8))
        XCTAssertTrue(pop.exists && octane.exists)
        // Snapshot coordinates once. Keep the comparator concrete so Swift
        // does not infer overloaded arithmetic through XCUIElement queries.
        let positions: [(name: String, frame: CGRect)] = [
            (pop.label, pop.frame), (hits.label, hits.frame), (octane.label, octane.frame)
        ]
        let ordered: [(name: String, frame: CGRect)] = positions.sorted { left, right in
            let verticalDistance: CGFloat = left.frame.minY - right.frame.minY
            if abs(verticalDistance) > 2 {
                return verticalDistance < 0
            }
            return left.frame.minX < right.frame.minX
        }
        let names: [String] = ordered.map { position in position.name }
        XCTAssertEqual(names, ["SiriusXM PopRocks", "SiriusXM Hits 1", "SiriusXM Octane"])
        hits.tap()
        app.buttons["miniplayer.open"].tap()
        let player = nowPlayingScreen(app)
        let station = player.staticTexts["nowplaying.station"]
        XCTAssertTrue(station.waitForExistence(timeout: 8))
        XCTAssertEqual(station.label, "SiriusXM Hits 1")
        for expected in ["SiriusXM Octane", "SiriusXM PopRocks"] {
            player.buttons["nowplaying.next"].tap()
            XCTAssertEqual(station.label, expected, "Next must follow the arranged Favorites order and wrap")
        }
        for expected in ["SiriusXM Octane", "SiriusXM Hits 1"] {
            player.buttons["nowplaying.previous"].tap()
            XCTAssertEqual(station.label, expected, "Previous must follow Favorites rather than the provider lineup")
        }
        player.buttons["nowplaying.close"].tap()
        XCTAssertTrue(player.waitForNonExistence(timeout: 8))

        // A new listening list must replace the old queue, not append to it.
        app.buttons["tab.search"].tap()
        let jazzShortcut = app.buttons["search.suggestion.jazz"]
        XCTAssertTrue(jazzShortcut.waitForExistence(timeout: 8))
        jazzShortcut.tap()
        let jazz = app.buttons["station.row.Jazz Cafe Radio"]
        XCTAssertTrue(jazz.waitForExistence(timeout: 8))
        jazz.tap()
        app.buttons["miniplayer.open"].tap()
        let searchPlayer = nowPlayingScreen(app)
        searchPlayer.buttons["nowplaying.next"].tap()
        XCTAssertEqual(searchPlayer.staticTexts["nowplaying.station"].label, "Jazz Cafe Radio",
                       "A one-result search must not return to the Favorites queue")
    }

    func testNowPlayingScreenShowsStateAndControls() throws {
        let app = launch(scenario: "UITestNowPlaying")

        // Mini player visible with the playing station.
        let activePlayer = app.buttons["miniplayer.open"]
        XCTAssertTrue(activePlayer.waitForExistence(timeout: 8))
        XCTAssertTrue((activePlayer.value as? String)?.contains("SiriusXM Hits 1") == true)
        let toggle = app.buttons["miniplayer.toggle"]
        if !toggle.waitForExistence(timeout: 8) {
            XCTFail("Mini player not visible. Hierarchy:\n\(app.debugDescription)")
        }

        // Tab navigation must remain usable while a station is playing.
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.category.account"].waitForExistence(timeout: 8),
                      "Tab bar must remain reachable during playback")
        capture(app, name: "Workspace — Settings with vinyl mini player")
        app.buttons["SXM"].tap()
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForExistence(timeout: 8))

        let miniPlayer = app.buttons["miniplayer.open"].firstMatch
        miniPlayer.tap()
        let player = nowPlayingScreen(app)
        XCTAssertTrue(player.buttons["nowplaying.close"].waitForExistence(timeout: 8))
        let records = player.descendants(matching: .any).matching(identifier: "nowplaying.vinyl")
        XCTAssertTrue(records.firstMatch.waitForExistence(timeout: 8))
        XCTAssertEqual(records.count, 1, "The full-player record must be unambiguous within its screen")
        XCTAssertTrue(player.buttons["nowplaying.stop"].exists)
        XCTAssertTrue(player.buttons["nowplaying.sleepTimer"].exists)
        assertBottomPlayerControls(app)
        let vinyl = records.firstMatch
        let status = player.descendants(matching: .any).matching(identifier: "nowplaying.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertEqual(vinyl.frame.midX, app.frame.midX, accuracy: 2)
        XCTAssertEqual(vinyl.frame.width, vinyl.frame.height, accuracy: 1)
        let stageMidY = (player.buttons["nowplaying.close"].frame.maxY + status.frame.minY) / 2
        XCTAssertEqual(vinyl.frame.midY, stageMidY, accuracy: 3,
                       "Center the record in the free space between the header and track details")
        capture(app, name: "Workspace — Now Playing with preserved vinyl")

        player.buttons["nowplaying.close"].tap()
        XCTAssertTrue(player.waitForNonExistence(timeout: 8), "Close must dismiss the presented player")
        XCTAssertTrue(app.buttons["miniplayer.open"].waitForExistence(timeout: 8),
                      "Closing the restyled player must retain playback and the vinyl mini player")
        app.buttons["miniplayer.open"].firstMatch.tap()
        let reopenedPlayer = nowPlayingScreen(app)
        XCTAssertTrue(reopenedPlayer.buttons["nowplaying.close"].waitForExistence(timeout: 8))

        // Switching stations repeatedly works without leaving the player.
        reopenedPlayer.buttons["nowplaying.next"].tap()
        XCTAssertTrue(reopenedPlayer.buttons["nowplaying.stop"].waitForExistence(timeout: 8))

        // Swipe the sheet down; playback continues in the mini player.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        from.press(forDuration: 0.1, thenDragTo: to)
        XCTAssertTrue(reopenedPlayer.waitForNonExistence(timeout: 8), "Swipe must dismiss the presented player")
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
        let player = nowPlayingScreen(app)
        XCTAssertTrue(player.buttons["nowplaying.close"].waitForExistence(timeout: 8))
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 8), .completed)
        assertBottomPlayerControls(app)
        let scroller = player.scrollViews["nowplaying.detailsScroll"]
        XCTAssertTrue(scroller.waitForExistence(timeout: 8), "Short layouts must allow the record and details to scroll")
        let card = player.descendants(matching: .any).matching(identifier: "nowplaying.controls").firstMatch
        let before = card.frame
        scroller.swipeUp()
        XCTAssertEqual(card.frame.minY, before.minY, accuracy: 2, "Scrolling details must not move transport controls")
        assertBottomPlayerControls(app)
        capture(app, name: "Bottom controls — compact-height player")
        player.buttons["nowplaying.close"].tap()
        XCTAssertTrue(player.waitForNonExistence(timeout: 8), "Close must dismiss the compact player")
        XCTAssertTrue(mini.waitForExistence(timeout: 8), "Closing still retains playback")
    }

    func testTranslucentHeaderSettingKeepsNavigationAndMiniPlayer() throws {
        let app = launch(scenario: "UITestNowPlaying")
        app.buttons["Settings"].tap()
        openSettingsCategory("app", in: app)

        let original = try settingValue("settings.liquidGlass", in: app)
        let updated = original == "1" ? "0" : "1"
        try toggleSetting("settings.liquidGlass", to: updated, in: app)

        let flatFavorites = app.buttons["tab.favorites"]
        if !flatFavorites.waitForExistence(timeout: 8) {
            XCTFail("Workspace navigation must remain available. Hierarchy:\n\(app.debugDescription)")
        }
        XCTAssertTrue(app.buttons["miniplayer.open"].exists)
        flatFavorites.tap()
        XCTAssertTrue(app.staticTexts["page.title.Favorites"].waitForExistence(timeout: 8))
        app.buttons["tab.settings"].tap()
        openSettingsCategory("app", in: app)
        XCTAssertEqual(try settingValue("settings.liquidGlass", in: app), updated,
                       "The navigation preference must survive leaving its Settings page")
        try toggleSetting("settings.liquidGlass", to: original, in: app)

        app.buttons["SXM"].tap()
        XCTAssertTrue(app.buttons["station.row.SiriusXM Hits 1"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["miniplayer.open"].isHittable)
        app.buttons["tab.settings"].tap()
        openSettingsCategory("app", in: app)
        XCTAssertEqual(try settingValue("settings.liquidGlass", in: app), original,
                       "The restored preference must also survive returning to Settings")
    }

    func testSettingsCategoriesExposeExistingControls() throws {
        let app = launch(scenario: "UITestBrowse")
        app.buttons["Settings"].tap()

        openSettingsCategory("account", in: app)
        XCTAssertTrue(app.buttons["settings.signOut"].waitForExistence(timeout: 8))
        capture(app, name: "Rounded type — Settings Account")
        openSettingsCategory("stations", in: app)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.siriusOnly").firstMatch.waitForExistence(timeout: 8))
        capture(app, name: "Rounded type — Settings Stations")
        openSettingsCategory("playback", in: app)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.cellular").firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.cellularBuffer").firstMatch.waitForExistence(timeout: 8))
        capture(app, name: "Rounded type — Settings Playback")
        let original = try settingValue("settings.cellular", in: app)
        let updated = original == "1" ? "0" : "1"
        try toggleSetting("settings.cellular", to: updated, in: app)
        openSettingsCategory("app", in: app)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "settings.liquidGlass").firstMatch.waitForExistence(timeout: 8))
        capture(app, name: "Rounded type — Settings App")
        openSettingsCategory("playback", in: app)
        XCTAssertEqual(try settingValue("settings.cellular", in: app), updated,
                       "The styled switch must keep its real Settings binding")
        try toggleSetting("settings.cellular", to: original, in: app)
    }

    func testWorkspaceHeaderAndBottomPlaybackShelfStayIndependentlyReachable() throws {
        let app = launch(scenario: "UITestNowPlaying")
        let first = app.buttons["tab.radio"]
        let last = app.buttons["tab.settings"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        XCTAssertTrue(last.isHittable)
        let mini = app.buttons["miniplayer.open"].firstMatch
        XCTAssertTrue(mini.waitForExistence(timeout: 8))
        let header = app.descendants(matching: .any).matching(identifier: "aether.navigation.header").firstMatch
        let shelf = app.descendants(matching: .any).matching(identifier: "aether.playback.shelf").firstMatch
        XCTAssertTrue(shelf.waitForExistence(timeout: 8))
        for identifier in ["miniplayer.open", "miniplayer.toggle", "miniplayer.stop"] {
            let control = shelf.buttons.matching(identifier: identifier)
            XCTAssertEqual(control.count, 1, "Each player action must retain its own identity within the shelf")
            XCTAssertTrue(control.firstMatch.isHittable)
            XCTAssertGreaterThanOrEqual(control.firstMatch.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.firstMatch.frame.height, 44)
        }
        XCTAssertTrue(header.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(header.frame.maxY, mini.frame.minY,
                                 "Navigation at the top and playback at the bottom must not overlap")
        XCTAssertGreaterThanOrEqual(first.frame.minX, app.frame.minX + 20)
        XCTAssertLessThanOrEqual(last.frame.maxX, app.frame.maxX - 20)
        app.buttons["tab.favorites"].tap()
        XCTAssertTrue(app.staticTexts["page.title.Favorites"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["miniplayer.stop"].isHittable)
        capture(app, name: "Workspace — compact controls and station clearance")
        app.buttons["miniplayer.stop"].tap()
        XCTAssertTrue(mini.waitForNonExistence(timeout: 8))
        XCTAssertTrue(last.isHittable)
    }

    func testTopRightUtilitiesToggleBackToTheStationTabWithoutStoppingPlayback() throws {
        let app = launch(scenario: "UITestNowPlaying")
        app.buttons["tab.favorites"].tap()
        XCTAssertTrue(app.staticTexts["page.title.Favorites"].waitForExistence(timeout: 8))
        for utility in ["settings", "search", "settings"] {
            app.buttons["tab.\(utility)"].tap()
            let content = utility == "settings"
                ? app.buttons["settings.category.account"] : app.textFields["search.field"]
            XCTAssertTrue(content.waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["miniplayer.open"].isHittable)
            app.buttons["tab.\(utility)"].tap()
            XCTAssertTrue(app.staticTexts["page.title.Favorites"].waitForExistence(timeout: 8),
                          "A second press must close the utility and return to the previous station tab")
        }
        app.buttons["tab.sxm"].tap()
        app.buttons["tab.settings"].tap()
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.buttons["station.row.SiriusXM Hits 1"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["miniplayer.open"].isHittable)
    }

    func testPresetFavoriteActionDoesNotStartPlayback() throws {
        let app = launch(scenario: "UITestFavorites")
        app.buttons["tab.favorites"].tap()
        let favorite = app.buttons["station.favorite.SiriusXM Hits 1"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 8))
        XCTAssertGreaterThanOrEqual(favorite.frame.width, 44)
        XCTAssertGreaterThanOrEqual(favorite.frame.height, 44)
        XCTAssertFalse(app.buttons["miniplayer.open"].exists)
        favorite.tap()
        XCTAssertTrue(app.buttons["station.row.SiriusXM Hits 1"].waitForNonExistence(timeout: 8))
        XCTAssertFalse(app.buttons["miniplayer.open"].exists, "Favorite and playback must be independent controls")
    }

    func testAccountPageCanCancelSignOutAndReturnToSettings() throws {
        let app = launch(scenario: "UITestBrowse")
        app.buttons["tab.settings"].tap()
        openSettingsCategory("account", in: app)
        app.buttons["settings.signOut"].tap()
        XCTAssertTrue(app.alerts["Sign out?"].waitForExistence(timeout: 8))
        app.alerts["Sign out?"].buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["settings.category.playback"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["tab.radio"].isHittable)
    }
}
