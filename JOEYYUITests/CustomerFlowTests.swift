import XCTest

@MainActor
final class CustomerFlowTests: XCTestCase {
    private let places = ["monorail-pike", "cloud-city", "five-stones-kirkland"]

    private func launch(welcome: Bool = false, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo"] + extra
        if !welcome { app.launchArguments.append("-skip-welcome") }
        app.launch()
        return app
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func expectProgress(_ value: String, in app: XCUIApplication) {
        let progress = app.descendants(matching: .any).matching(identifier: "card.progress").firstMatch
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", value), object: progress
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    private func contentBottom(in app: XCUIApplication) -> CGFloat {
        let bar = app.tabBars.firstMatch
        return bar.exists ? bar.frame.minY : app.frame.maxY
    }

    private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        let bottom = contentBottom(in: app)
        for _ in 0..<10 where !element.isHittable || element.frame.maxY > bottom {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertLessThanOrEqual(element.frame.maxY, bottom)
    }

    private func openCard(_ id: String, in app: XCUIApplication) {
        let heading = app.staticTexts["heading.home"]
        for _ in 0..<6 where !heading.isHittable { app.swipeDown() }
        let card = app.buttons["card.\(id)"]
        reach(card, in: app)
        card.tap()
    }

    func testHomeGivesEachBusinessAFullWidthCard() {
        let app = launch()
        for tab in ["Home", "Search", "Redeemed", "You"] {
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", tab)).firstMatch.exists)
        }
        for id in places {
            let card = app.buttons["card.\(id)"]
            reach(card, in: app)
            XCTAssertTrue(card.isHittable)
            XCTAssertGreaterThan(card.frame.width, min(app.frame.width * 0.8, 650))
            XCTAssertGreaterThan(card.frame.height, 280)
            XCTAssertLessThan(card.frame.maxY, contentBottom(in: app))
        }
        XCTAssertFalse(app.staticTexts["Reward ready"].exists)
        XCTAssertFalse(app.staticTexts["6/6"].exists)
        capture("Home - Seattle and Kirkland cards", app: app)
    }

    func testWideEstablishmentKeepsArtworkAndPunchCardSeparate() throws {
        let app = launch()
        guard app.frame.width >= 900 else { throw XCTSkip("Requires a wide iPad simulator.") }
        openCard("monorail-pike", in: app)
        let heading = app.staticTexts["Monorail Espresso"]
        let progress = app.descendants(matching: .any).matching(identifier: "card.progress").firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(progress.frame.minX, heading.frame.maxX)
        XCTAssertLessThan(progress.frame.midY, heading.frame.minY)
        expectProgress("5 of 8 stamps", in: app)
        capture("Wide establishment - cover and punch card", app: app)
        try audit(app)
    }

    func testFullCardWaitsForClaimAndCancellationKeepsItFull() {
        let app = launch()
        openCard("cloud-city", in: app)
        expectProgress("6 of 6 stamps", in: app)
        XCTAssertFalse(app.buttons["detail.simulateVisit"].exists)
        capture("Cloud City - complete card", app: app)
        app.buttons["detail.claim"].tap()
        app.alerts.buttons["Cancel"].tap()
        expectProgress("6 of 6 stamps", in: app)
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-welcome"]
        app.launch()
        openCard("cloud-city", in: app)
        expectProgress("6 of 6 stamps", in: app)
        app.buttons["detail.claim"].tap()
        app.alerts.buttons["Claim reward"].tap()
        XCTAssertTrue(app.staticTexts["coupon.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["coupon.title"].label, "Brewed coffee")
        capture("Cloud City - claimed coupon", app: app)
        app.buttons["Done"].tap()
        expectProgress("0 of 6 stamps", in: app)
        XCTAssertFalse(app.buttons["detail.claim"].exists)
        XCTAssertTrue(app.buttons["detail.simulateVisit"].exists)
        app.tabBars.buttons["Redeemed"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'coupon.cloud-city.'"
        )).count, 2)
    }

    func testCollectingFillsCardWithoutAutomaticCoupon() {
        let app = launch()
        openCard("monorail-pike", in: app)
        expectProgress("5 of 8 stamps", in: app)
        for _ in 0..<3 { app.buttons["detail.simulateVisit"].tap() }
        expectProgress("8 of 8 stamps", in: app)
        XCTAssertTrue(app.buttons["detail.claim"].exists)
        XCTAssertFalse(app.buttons["detail.simulateVisit"].exists)
        capture("Monorail - full punch card", app: app)
        app.tabBars.buttons["Redeemed"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'coupon.monorail-pike.'"
        )).count, 1)
    }

    func testRedeemedSamplesCanBeUsedOnceWithoutChangingStamps() {
        let app = launch()
        app.tabBars.buttons["Redeemed"].tap()
        for id in places {
            XCTAssertEqual(app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH %@", "coupon.\(id)."
            )).count, 1)
        }
        capture("Redeemed - sample tickets", app: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'coupon.cloud-city.'")).firstMatch.tap()
        XCTAssertEqual(app.staticTexts["coupon.title"].label, "Brewed coffee")
        app.buttons["coupon.wallet"].tap()
        XCTAssertTrue(app.staticTexts["Apple Wallet coupon passes aren't implemented yet."].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.buttons["coupon.use"].tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["coupon.status"].label, "AVAILABLE")
        app.buttons["coupon.use"].tap()
        app.alerts.buttons["Mark as used"].tap()
        let used = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'USED'"), object: app.staticTexts["coupon.status"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [used], timeout: 3), .completed)
        XCTAssertFalse(app.buttons["coupon.use"].exists)
        app.navigationBars.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Used"].exists)
        app.tabBars.buttons["Home"].tap()
        openCard("cloud-city", in: app)
        expectProgress("6 of 6 stamps", in: app)
    }

    func testSearchUsesBusinessNameAndExactClientIDNotLocation() {
        let app = launch()
        app.tabBars.buttons["Search"].tap()
        XCTAssertFalse(app.buttons["search.monorail-pike"].exists)
        let search = app.textFields["search.query"]
        search.tap()
        search.typeText("6a2e3d81-7b49-4f12-a0c3-819d62e00101")
        XCTAssertTrue(app.buttons["search.monorail-pike"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["search.cloud-city"].exists)
        app.buttons["Clear search"].tap()
        search.tap()
        search.typeText("Kirkland")
        XCTAssertTrue(app.staticTexts["No matching business"].exists)
        XCTAssertFalse(app.staticTexts["Check the name or client ID."].exists)
        app.buttons["Clear search"].tap()
        search.tap()
        search.typeText("5 Stones")
        app.buttons["search.five-stones-kirkland"].tap()
        expectProgress("2 of 10 stamps", in: app)
        app.buttons["detail.wallet"].tap()
        XCTAssertTrue(app.staticTexts["Apple Wallet isn't implemented yet."].waitForExistence(timeout: 3))
    }

    func testDiscoveryGallerySwipesAndAddsACardWithoutChangingExistingCards() {
        let app = launch()
        XCTAssertFalse(app.buttons["card.gloom-coffee"].exists)
        app.tabBars.buttons["Search"].tap()
        let gallery = app.scrollViews["search.discovery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["discover.saint-bread"].isHittable)
        capture("Discoverable - Saint Bread", app: app)
        gallery.swipeLeft()
        XCTAssertTrue(app.buttons["discover.book-larder"].isHittable)
        capture("Discoverable - Book Larder", app: app)
        gallery.swipeLeft()
        let gloom = app.buttons["discover.gloom-coffee"]
        XCTAssertTrue(gloom.isHittable)
        capture("Discoverable - Gloom Coffee", app: app)
        gloom.tap()
        expectProgress("0 of 8 stamps", in: app)
        let join = app.buttons["detail.join"]
        reach(join, in: app)
        join.tap()
        app.buttons["detail.simulateVisit"].tap()
        expectProgress("1 of 8 stamps", in: app)
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["card.gloom-coffee"].waitForExistence(timeout: 3))
        openCard("monorail-pike", in: app)
        expectProgress("5 of 8 stamps", in: app)
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-welcome"]
        app.launch()
        openCard("gloom-coffee", in: app)
        expectProgress("1 of 8 stamps", in: app)
    }

    func testDiscoveryPostersSupportDarkModeAndLargestTextWithReducedMotion() {
        for mode in ["Dark", "Light"] {
            let extra = mode == "Light" ? [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                "-reduce-motion"
            ] : []
            let app = launch(extra: extra)
            app.tabBars.buttons["You"].tap()
            app.buttons["settings.appearance"].tap()
            app.buttons[mode].tap()
            app.tabBars.buttons["Search"].tap()
            let gallery = app.scrollViews["search.discovery"]
            XCTAssertTrue(gallery.waitForExistence(timeout: 3))
            for id in ["saint-bread", "book-larder", "gloom-coffee"] {
                let poster = app.buttons["discover.\(id)"]
                reach(poster, in: app)
                XCTAssertGreaterThan(poster.frame.width, app.frame.width * 0.7)
                capture("Discovery poster - \(id) - \(mode)", app: app)
                if id != "gloom-coffee" { gallery.swipeLeft() }
            }
            app.buttons["discover.gloom-coffee"].tap()
            expectProgress("0 of 8 stamps", in: app)
            let join = app.buttons["detail.join"]
            reach(join, in: app)
            XCTAssertTrue(join.isHittable)
            app.terminate()
        }
    }

    func testProgramDetailsRetainSourcesClientIDAndActivity() {
        let app = launch()
        openCard("monorail-pike", in: app)
        app.buttons["Program details"].tap()
        let identifier = app.staticTexts["detail.clientID"]
        reach(identifier, in: app)
        XCTAssertEqual(identifier.label, "6A2E3D81-7B49-4F12-A0C3-819D62E00101")
        XCTAssertTrue(app.buttons["Copy client ID"].exists)
        XCTAssertTrue(app.buttons["Business website"].exists)
        let activity = app.buttons["See all activity"]
        reach(activity, in: app)
        activity.tap()
        let joined = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Program joined")).firstMatch
        XCTAssertTrue(joined.waitForExistence(timeout: 3))
    }

    func testFreshInstallChoosesCustomerAndRemembersCompletion() {
        let app = launch(welcome: true)
        XCTAssertFalse(app.staticTexts["Stamp cards"].exists)
        XCTAssertTrue(app.buttons["setup.customer"].isHittable)
        XCTAssertTrue(app.buttons["setup.business"].isHittable)
        XCTAssertFalse(app.buttons["setup.close"].exists)
        capture("Setup - Customer and Business", app: app)
        app.buttons["setup.customer"].tap()
        XCTAssertTrue(app.staticTexts["heading.home"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["heading.home"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["setup.customer"].exists)
    }

    func testBusinessChoiceOpensBusinessSideAndIsRemembered() {
        let app = launch(welcome: true)
        app.buttons["setup.business"].tap()
        XCTAssertTrue(app.staticTexts["heading.businessWelcome"].waitForExistence(timeout: 3))
        capture("Setup - Business destination", app: app)
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["heading.businessWelcome"].waitForExistence(timeout: 3))
        app.buttons["business.switch"].tap()
        XCTAssertTrue(app.buttons["setup.customer"].waitForExistence(timeout: 3))
        app.buttons["setup.customer"].tap()
        XCTAssertTrue(app.staticTexts["heading.home"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["heading.home"].waitForExistence(timeout: 3))
    }

    func testSetupSupportsLargestTextAndReduceMotion() {
        let app = launch(welcome: true, extra: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            "-reduce-motion"
        ])
        let business = app.buttons["setup.business"]
        for _ in 0..<6 where !business.isHittable { app.swipeUp() }
        XCTAssertTrue(business.isHittable)
        capture("Setup - largest text and Reduce Motion", app: app)
        business.tap()
        XCTAssertTrue(app.staticTexts["heading.businessWelcome"].waitForExistence(timeout: 3))
        let switchSide = app.buttons["business.switch"]
        for _ in 0..<6 where !switchSide.isHittable { app.swipeDown() }
        switchSide.tap()
        let customer = app.buttons["setup.customer"]
        XCTAssertTrue(customer.waitForExistence(timeout: 3))
        for _ in 0..<6 where !customer.isHittable { app.swipeDown() }
        XCTAssertTrue(customer.isHittable)
        customer.tap()
        XCTAssertTrue(app.staticTexts["heading.home"].waitForExistence(timeout: 3))
    }

    func testSetupAndSettingsContrastInLightAndDark() throws {
        let app = launch()
        for mode in ["Light", "Dark"] {
            app.tabBars.buttons["You"].tap()
            app.buttons["settings.appearance"].tap()
            app.buttons[mode].tap()
            let setup = app.buttons["settings.setup"]
            try XCTContext.runActivity(named: "Settings fully visible - \(mode)") { _ in
                reach(setup, in: app)
                capture("You - \(mode)", app: app)
                try audit(app)
            }
            setup.tap()
            XCTAssertTrue(app.buttons["setup.customer"].waitForExistence(timeout: 3))
            try audit(app)
            capture("Role landing - \(mode)", app: app)
            app.buttons["setup.business"].tap()
            XCTAssertTrue(app.staticTexts["heading.businessWelcome"].waitForExistence(timeout: 3))
            // Business dismisses the setup cover; audit once it has finished sliding away.
            XCTAssertTrue(app.buttons["setup.customer"].waitForNonExistence(timeout: 3))
            try audit(app)
            capture("Business welcome - \(mode)", app: app)
            app.buttons["business.switch"].tap()
            XCTAssertTrue(app.buttons["setup.close"].waitForExistence(timeout: 3))
            app.buttons["setup.customer"].tap()
            XCTAssertTrue(app.staticTexts["heading.home"].waitForExistence(timeout: 3))
        }
    }

    func testAppearanceAndAccentPersistWithoutProfileScaffolding() {
        let app = launch()
        app.tabBars.buttons["You"].tap()
        XCTAssertFalse(app.staticTexts["Local profile"].exists)
        XCTAssertFalse(app.staticTexts["No sign-in"].exists)
        app.buttons["settings.appearance"].tap()
        app.buttons["Dark"].tap()
        app.buttons["settings.accent.Purple"].tap()
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-welcome"]
        app.launch()
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["settings.appearance"].label.contains("Dark"))
        XCTAssertTrue(app.buttons["settings.accent.Purple"].isSelected)
        app.tabBars.buttons["Home"].tap()
        capture("Home - dark purple", app: app)
    }

    func testYouKeepsOnlyPreferencesAndSetup() {
        let app = launch()
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["settings.appearance"].exists)
        XCTAssertTrue(app.switches["Reward reminders"].exists)
        XCTAssertTrue(app.switches["News & offers"].exists)
        XCTAssertTrue(app.staticTexts["Notifications aren't connected yet."].exists)
        XCTAssertFalse(app.staticTexts["Saved on this device. Notifications aren't connected yet."].exists)
        XCTAssertFalse(app.buttons["Data & privacy"].exists)
        XCTAssertFalse(app.buttons["For businesses"].exists)
        XCTAssertFalse(app.buttons["profile.delete"].exists)
        XCTAssertFalse(app.buttons["profile.reset"].exists)
        XCTAssertFalse(app.staticTexts["Prototype"].exists)
        let setup = app.buttons["settings.setup"]
        reach(setup, in: app)
        capture("You - appearance, notifications and setup", app: app)
        setup.tap()
        XCTAssertTrue(app.buttons["setup.customer"].waitForExistence(timeout: 3))
        app.buttons["setup.business"].tap()
        XCTAssertTrue(app.staticTexts["heading.businessWelcome"].waitForExistence(timeout: 3))
        app.buttons["business.switch"].tap()
        XCTAssertTrue(app.buttons["setup.customer"].waitForExistence(timeout: 3))
        app.buttons["setup.customer"].tap()
        XCTAssertTrue(app.staticTexts["heading.home"].waitForExistence(timeout: 3))
    }

    func testArchiveCanBeRestored() {
        let app = launch()
        openCard("monorail-pike", in: app)
        app.buttons["Card options"].tap()
        app.buttons["Archive card"].tap()
        app.buttons["Archive card"].tap()
        app.buttons["Archived cards"].tap()
        app.buttons["Restore"].tap()
        XCTAssertTrue(app.staticTexts["No archived cards"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["card.monorail-pike"].exists)
    }

    func testReplayingSetupPreservesCardsCouponsAndPreferences() {
        let app = launch()
        app.buttons["favorite.monorail-pike"].tap()
        app.buttons["home.collection"].tap()
        app.buttons["Favorites"].tap()
        openCard("monorail-pike", in: app)
        app.buttons["detail.simulateVisit"].tap()
        app.tabBars.buttons["You"].tap()
        let reminders = app.switches["Reward reminders"]
        reminders.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(reminders.value as? String, "1")
        let setup = app.buttons["settings.setup"]
        reach(setup, in: app)
        setup.tap()
        app.buttons["setup.customer"].tap()
        XCTAssertTrue(app.staticTexts["heading.home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
        XCTAssertTrue(app.buttons["home.collection"].label.contains("All places"))
        XCTAssertFalse(app.buttons["detail.simulateVisit"].exists)
        app.tabBars.buttons["You"].tap()
        XCTAssertEqual(app.switches["Reward reminders"].value as? String, "1")
        app.tabBars.buttons["Redeemed"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'coupon.'"
        )).count, 3)
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["favorite.monorail-pike"].isSelected)
        openCard("monorail-pike", in: app)
        expectProgress("6 of 8 stamps", in: app)
    }

    func testCardsAndCouponsContrastAndTextClippingInLightAndDark() throws {
        let app = launch()
        for mode in ["Light", "Dark"] {
            app.tabBars.buttons["You"].tap()
            app.buttons["settings.appearance"].tap()
            app.buttons[mode].tap()
            app.tabBars.buttons["Home"].tap()
            try audit(app)
            capture("Home - \(mode)", app: app)
            for id in places {
                openCard(id, in: app)
                try audit(app)
                capture("\(id) - \(mode)", app: app)
                app.navigationBars.buttons["Back"].tap()
            }
            app.tabBars.buttons["Redeemed"].tap()
            try audit(app)
            for id in places {
                app.buttons.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "coupon.\(id)."
                )).firstMatch.tap()
                try audit(app)
                capture("\(id) coupon - \(mode)", app: app)
                app.navigationBars.buttons["Back"].tap()
            }
        }
    }

    func testLargestTextSizeCanClaimAndUseCoupon() throws {
        let app = launch(extra: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])
        let card = app.buttons["card.cloud-city"]
        reach(card, in: app)
        card.tap()
        let claim = app.buttons["detail.claim"]
        reach(claim, in: app)
        capture("Cloud City - largest text", app: app)
        claim.tap()
        app.alerts.buttons["Claim reward"].tap()
        XCTAssertTrue(app.staticTexts["coupon.title"].waitForExistence(timeout: 3))
        let use = app.buttons["coupon.use"]
        reach(use, in: app)
        capture("Coupon - largest text", app: app)
        use.tap()
        XCTAssertTrue(app.alerts.buttons["Mark as used"].waitForExistence(timeout: 3))
        app.alerts.buttons["Cancel"].tap()
        app.buttons["Done"].tap()
        expectProgress("0 of 6 stamps", in: app)
        let progress = app.descendants(matching: .any).matching(identifier: "card.progress").firstMatch
        reach(progress, in: app)
        capture("Cloud City - unpunched card at largest text", app: app)
        try app.performAccessibilityAudit(for: [.textClipped])
    }

    func testReduceMotionCanCollectAndClaim() {
        let app = launch(extra: ["-reduce-motion"])
        openCard("monorail-pike", in: app)
        for _ in 0..<3 { app.buttons["detail.simulateVisit"].tap() }
        expectProgress("8 of 8 stamps", in: app)
        app.buttons["detail.claim"].tap()
        app.alerts.buttons["Claim reward"].tap()
        XCTAssertTrue(app.staticTexts["coupon.title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["coupon.title"].label, "Espresso")
    }

    func testFavoritesIncludeUnfinishedCardsAndPersistAcrossRelaunch() {
        let app = launch()
        app.buttons["favorite.monorail-pike"].tap()
        app.buttons["home.collection"].tap()
        app.buttons["Favorites"].tap()
        XCTAssertTrue(app.buttons["card.monorail-pike"].exists)
        XCTAssertFalse(app.buttons["card.cloud-city"].exists)
        openCard("monorail-pike", in: app)
        expectProgress("5 of 8 stamps", in: app)
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-welcome"]
        app.launch()
        XCTAssertTrue(app.buttons["favorite.monorail-pike"].isSelected)
        app.buttons["home.collection"].tap()
        app.buttons["Favorites"].tap()
        app.buttons["favorite.monorail-pike"].tap()
        XCTAssertTrue(app.staticTexts["No favorites"].exists)
        XCTAssertFalse(app.staticTexts["Save a place with its star. Unfinished cards can be favorites too."].exists)
    }

    func testGroupsCanCollectUnfinishedAndFullCardsRenameAndDelete() {
        let app = launch()
        app.buttons["favorite.monorail-pike"].tap()
        app.buttons["home.groups"].tap()
        app.buttons["group.create"].tap()
        app.textFields["group.name"].tap()
        app.textFields["group.name"].typeText("Weekends")
        for id in ["monorail-pike", "cloud-city"] {
            let toggle = app.switches["group.place.\(id)"]
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "1")
        }
        app.buttons["group.save"].tap()
        XCTAssertTrue(app.buttons["group.edit.Weekends"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.buttons["home.collection"].tap()
        app.buttons["Weekends"].tap()
        XCTAssertTrue(app.buttons["card.monorail-pike"].exists)
        XCTAssertTrue(app.buttons["card.cloud-city"].exists)
        XCTAssertFalse(app.buttons["card.five-stones-kirkland"].exists)
        capture("Group - unfinished and completed cards", app: app)
        app.buttons["home.groups"].tap()
        app.buttons["group.options.Weekends"].tap()
        app.buttons["Rename"].tap()
        let name = app.textFields["group.name"]
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "Saturday")
        app.buttons["group.save"].tap()
        let group = app.buttons["group.edit.Saturday"]
        XCTAssertTrue(group.waitForExistence(timeout: 3))
        group.tap()
        app.buttons["group.delete"].tap()
        app.alerts.buttons["group.cancelDelete"].firstMatch.tap()
        XCTAssertEqual(app.textFields["group.name"].value as? String, "Saturday")
        app.buttons["group.delete"].tap()
        app.alerts.buttons["group.confirmDelete"].firstMatch.tap()
        XCTAssertFalse(app.buttons["group.edit.Saturday"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["home.collection"].label.contains("All places"))
        XCTAssertTrue(app.buttons["card.monorail-pike"].exists)
        XCTAssertTrue(app.buttons["card.five-stones-kirkland"].exists)
        XCTAssertTrue(app.buttons["favorite.monorail-pike"].isSelected)
        openCard("monorail-pike", in: app)
        expectProgress("5 of 8 stamps", in: app)
        app.tabBars.buttons["Redeemed"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'coupon.'"
        )).count, 3)
    }

    func testGroupCanBeDeletedFromItsOptionsMenu() {
        let app = launch()
        app.buttons["home.groups"].tap()
        app.buttons["group.create"].tap()
        app.textFields["group.name"].tap()
        app.textFields["group.name"].typeText("Nearby")
        app.buttons["group.save"].tap()
        XCTAssertTrue(app.buttons["group.edit.Nearby"].waitForExistence(timeout: 3))
        app.buttons["group.options.Nearby"].tap()
        app.buttons["Delete group"].tap()
        app.alerts.buttons["group.cancelDelete"].firstMatch.tap()
        XCTAssertTrue(app.buttons["group.edit.Nearby"].exists)
        app.buttons["group.options.Nearby"].tap()
        app.buttons["Delete group"].tap()
        app.alerts.buttons["group.confirmDelete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No groups"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["card.monorail-pike"].exists)
    }

    func testBrandingPreviewUsesPhotoPickerAndHandlesImageErrors() throws {
        let app = launch()
        openCard("monorail-pike", in: app)
        app.buttons["Card options"].tap()
        app.buttons["Preview branding"].tap()
        XCTAssertTrue(app.buttons["branding.choosePhoto"].exists)
        app.buttons["branding.choosePhoto"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        let url = app.textFields["branding.coverURL"]
        url.tap()
        url.typeText("http://example.com/image.jpg")
        app.buttons["branding.applyURL"].tap()
        XCTAssertTrue(app.alerts["Couldn't update artwork"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Use an HTTPS image URL without embedded credentials."].exists)
        app.alerts.buttons["OK"].tap()
        url.tap()
        url.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: "http://example.com/image.jpg".count)
                + "https://images.example.invalid/cover.jpg"
        )
        app.buttons["branding.applyURL"].tap()
        app.buttons["Done"].tap()
        let retry = app.buttons["Retry image"]
        XCTAssertTrue(retry.waitForExistence(timeout: 25))
        capture("Unavailable artwork - retry", app: app)
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 25))
        try audit(app)
        expectProgress("5 of 8 stamps", in: app)
    }

    func testDetailCanCreateAGroupAndChangeItsMembership() {
        let app = launch()
        openCard("cloud-city", in: app)
        app.buttons["Card options"].tap()
        app.buttons["Groups"].tap()
        app.buttons["New group"].tap()
        XCTAssertEqual(app.switches["group.place.cloud-city"].value as? String, "1")
        app.textFields["group.name"].tap()
        app.textFields["group.name"].typeText("Nearby")
        app.buttons["group.save"].tap()
        let toggle = app.switches["Nearby"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        app.buttons["Done"].tap()
        app.navigationBars.buttons["Back"].tap()
        app.buttons["home.collection"].tap()
        app.buttons["Nearby"].tap()
        XCTAssertTrue(app.staticTexts["No places in this group"].waitForExistence(timeout: 3))
    }

    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [.contrast, .textClipped]) { issue in
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            let underTabBar = app.tabBars.firstMatch.exists &&
                element.frame.intersects(app.tabBars.firstMatch.frame)
            let underScrollEdge = app.images.matching(identifier: "AdditionalDimmingOverlay")
                .allElementsBoundByIndex.contains { element.frame.intersects($0.frame) }
            // Native floating bars and scroll-edge overlays fade underlying content.
            if underTabBar || underScrollEdge { return true }
            let attachment = XCTAttachment(string: "\(issue.detailedDescription)\n\(element.debugDescription)")
            attachment.name = "App-owned contrast issue"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return false
        }
    }
}
