# Bussin iOS Phase 4 — Share-Ready Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A classmate taps a TestFlight link, installs Bussin, understands what it does on first open, and never hits a dead end when something is off. Chris can see in PostHog how people move through the app.

**Architecture:** One new first-open screen (`WelcomeView`) gated by a saved flag. Two small Home notices for "location is off" and "nothing is running". A handful of new named analytics events. Release settings and a privacy page so the build passes Apple's TestFlight checks. No new dependencies.

**Tech Stack:** Swift, SwiftUI, XCTest, XcodeGen, GitHub Pages for the privacy page, App Store Connect for TestFlight.

**Conventions:** branch `ios-phase-4`; `cd ios && xcodegen generate` after any file add/remove or `project.yml` change; test with `xcodebuild test -project ios/Bussin.xcodeproj -scheme Bussin -destination 'platform=iOS Simulator,name=iPhone 17'`; `git add` only named files; follow DESIGN.md.

**Models:** Sonnet for Tasks 1–3 (screens). Haiku for Tasks 4–5 and 7 (settings, page, chores). Fable or Opus for the Build 3 log wording in Task 7.

## Decisions made with Chris (Nov 13)

1. **Public TestFlight link.** Anyone with the link can install. Apple reviews the first build, usually within about a day.
2. **Share as soon as Apple approves.** No waiting on NYU Transportation. The risk stays on the books: if NYU or Passio objects, the feed could be blocked and the app would show no buses. The app says plainly that it is not an official NYU app.
3. **One welcome card that also outlines the features**, with the location request on the same card.

## Out of scope

- The layered Icon Composer icon. The logo isn't final, so the flat Station sign icon ships to testers.
- The App Store itself. TestFlight only.
- Service alerts, crowding, and the rest of Phase 5.

---

### Task 1: Welcome card

**Files:** Create `ios/Bussin/Views/WelcomeView.swift`. Modify `ios/Bussin/Views/MapScreen.swift`, `ios/Bussin/App/Analytics.swift`.

- [ ] **Step 1:** `WelcomeView.swift`:

```swift
import SwiftUI

/// Shown once, the first time Bussin opens: what the app does and why it asks for location.
struct WelcomeView: View {
    let onContinue: () -> Void

    private struct Feature: Identifiable {
        let icon: String, tint: Color, title: String, detail: String
        var id: String { title }
    }

    private let features = [
        Feature(icon: "bus.fill", tint: .blue, title: "See every shuttle live",
                detail: "Buses move on the map as they drive, with arrival times for each stop."),
        Feature(icon: "figure.walk", tint: .green, title: "Ride or walk?",
                detail: "Search any place and Bussin tells you which is faster right now."),
        Feature(icon: "star.fill", tint: .yellow, title: "Keep your places",
                detail: "Star where you go most and it waits on the home screen."),
        Feature(icon: "location.fill", tint: .blue, title: "Why it asks for your location",
                detail: "To find your nearest stop and time your walk. Bussin never collects it."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)
            Text("Bussin").font(.largeTitle.bold())
            Text("NYU's free shuttles, live.")
                .font(.title3).foregroundStyle(.secondary)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 24) {
                ForEach(features) { f in
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: f.icon)
                            .font(.title2).foregroundStyle(f.tint)
                            .frame(width: RowMetrics.iconColumn)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.title).font(.headline)
                            Text(f.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Spacer(minLength: 24)
            Button(action: onContinue) {
                Text("Continue").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            Text("Not an official NYU app. Bus positions come from NYU's Passio GO feed.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .padding(24)
        .background(.background)
    }
}

#Preview { WelcomeView(onContinue: {}) }
```

- [ ] **Step 2:** In `MapScreen`:
  - Add `@AppStorage("hasSeenWelcome") private var hasSeenWelcome = false`.
  - `sheetShown` starts as `false`. The panel appears only once the welcome is done.
  - Replace the `.onAppear` location lines with:

```swift
        .fullScreenCover(isPresented: .constant(!hasSeenWelcome)) {
            WelcomeView {
                Analytics.capture("onboarding_completed")
                hasSeenWelcome = true
                startLocation()
                sheetShown = true
            }
        }
        .onAppear {
            guard hasSeenWelcome else { return }
            startLocation()
            sheetShown = true
        }
```

  - Add:

```swift
    private func startLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
```

  - Debug shortcut: `-resetWelcome YES` clears the flag at launch so the card can be re-checked.

- [ ] **Step 3:** Build, run the 39 tests, check in the simulator on a fresh install (welcome shows, Continue brings up Apple's prompt, the map and panel follow; second launch goes straight to the map). Commit — `Welcome new riders with one card that explains the app and the location request`

### Task 2: Notices for "location is off" and "nothing is running"

**Files:** Create `ios/Bussin/Models/ServiceStatus.swift`, `ios/BussinTests/ServiceStatusTests.swift`. Modify `ios/Bussin/Views/HomeView.swift`, `ios/Bussin/Views/SheetHost.swift`, `ios/Bussin/Views/MapScreen.swift`.

- [ ] **Step 1: Failing tests**

```swift
import XCTest
@testable import Bussin

final class ServiceStatusTests: XCTestCase {
    func testQuietWhenBusesAreOut() {
        XCTAssertNil(ServiceStatus.notice(feed: .live, busCount: 3))
    }

    func testSaysNothingIsRunningWhenTheFeedIsLiveButEmpty() {
        XCTAssertEqual(ServiceStatus.notice(feed: .live, busCount: 0), .nothingRunning)
    }

    func testStaysQuietWhileTheFirstUpdateLoads() {
        XCTAssertNil(ServiceStatus.notice(feed: .loading, busCount: 0), "don't claim nothing is running before we know")
    }

    func testAFeedProblemIsNotTheSameAsNoService() {
        XCTAssertEqual(ServiceStatus.notice(feed: .stale("x"), busCount: 0), .feedDown)
        XCTAssertEqual(ServiceStatus.notice(feed: .stale("x"), busCount: 4), .feedDown)
    }
}
```

- [ ] **Step 2: Implement** `ServiceStatus.swift`:

```swift
import Foundation

/// What, if anything, Home should say about service as a whole.
enum ServiceStatus: Equatable {
    case nothingRunning     // the feed works and reports no shuttles out
    case feedDown           // we can't reach the feed, so we don't know

    @MainActor
    static func notice(feed: ShuttleStore.FeedState, busCount: Int) -> ServiceStatus? {
        switch feed {
        case .loading: return nil
        case .stale: return .feedDown
        case .live: return busCount == 0 ? .nothingRunning : nil
        }
    }

    var title: String {
        switch self {
        case .nothingRunning: return "No shuttles are running right now"
        case .feedDown: return "Can't reach live bus data"
        }
    }

    var detail: String {
        switch self {
        case .nothingRunning: return "Routes and stops are still here. Buses appear when service starts."
        case .feedDown: return "Check your connection. Bussin keeps trying and shows the last buses it saw."
        }
    }
}
```

- [ ] **Step 3: Home.** Under the search row:
  - If `ServiceStatus.notice(feed: store.feedState, busCount: store.trackedBuses.count)` is non-nil, one row with a `moon.zzz.fill` (nothing running) or `wifi.slash` (feed down) icon in the shared icon column, the title in `.headline`, the detail in `.subheadline` secondary.
  - If location is denied or restricted, one row: `location.slash.fill`, "Location is off", "Turn it on to see your nearest stop and walking times.", and a button "Open Settings" that opens `UIApplication.openSettingsURLString`.
  - `HomeView` gets `let locationDenied: Bool`, passed from `MapScreen` through `SheetHost`. `MapScreen` reads `locationManager.authorizationStatus` (`.denied` or `.restricted`).
  - While location is denied, the "Nearest stop" header reads "Nearest stop to 715 Broadway", since that is the stand-in.

- [ ] **Step 4:** Run tests (43 expected), check each notice in the simulator (airplane-style failure by blocking the feed host is not practical; check `nothingRunning` late at night or with `-place` unaffected, and location-off by denying the prompt). Commit — `Say so when nothing is running, the feed is down, or location is off`

### Task 3: Funnel events

**Files:** Modify `ios/Bussin/App/Analytics.swift`, `SearchView.swift`, `TripView.swift`, `MapScreen.swift`.

Events already sent: `app_opened`, `route_viewed`, `stop_viewed`, `bus_viewed`, `trip_planned`, `no_good_option`. Add:

| Event | When | Properties |
|---|---|---|
| `onboarding_completed` | Continue on the welcome card (Task 1) | none |
| `location_permission` | The first time the status is known each launch | `status`: allowed / denied / not_asked |
| `search_opened` | The search screen appears | none |
| `place_selected` | A search result, favorite, or recent is opened | `source`: search / favorite / recent |
| `favorite_changed` | The star is tapped | `added`: true/false |
| `trip_option_selected` | The rider taps a different option on the trip screen | `choice`: shuttle / walk |

No event carries a place name, an address, or coordinates.

- [ ] Add the calls, build, run tests, confirm each event prints in the Xcode console in a debug run. Commit — `Track the steps from opening the app to planning a trip`
- [ ] **With Chris's go-ahead** (it changes his PostHog project): create a funnel insight `app_opened → search_opened → place_selected → trip_planned`, and turn on "Discard client IP data" in the PostHog project settings so approximate location from IP addresses isn't stored.

### Task 4: Release settings Apple checks

**Files:** Modify `ios/project.yml`. Create `ios/Bussin/PrivacyInfo.xcprivacy`.

- [ ] `project.yml`, Bussin target: `MARKETING_VERSION: 1.0.0`; `info.properties` gains `CFBundleDisplayName: Bussin`, `CFBundleShortVersionString: $(MARKETING_VERSION)`, `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`, `ITSAppUsesNonExemptEncryption: false` (the app only uses standard HTTPS, which skips Apple's export question on every upload).
- [ ] `PrivacyInfo.xcprivacy`, declaring the one "required reason" API the app's own code uses (UserDefaults, for favorites and the welcome flag) and what it collects:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array>
		<dict>
			<key>NSPrivacyCollectedDataType</key>
			<string>NSPrivacyCollectedDataTypeProductInteraction</string>
			<key>NSPrivacyCollectedDataTypeLinked</key>
			<false/>
			<key>NSPrivacyCollectedDataTypeTracking</key>
			<false/>
			<key>NSPrivacyCollectedDataTypePurposes</key>
			<array>
				<string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
			</array>
		</dict>
	</array>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

- [ ] `xcodegen generate`, then a Release build for a generic iOS device to confirm it compiles without the debug-only code: `xcodebuild -project ios/Bussin.xcodeproj -scheme Bussin -configuration Release -destination 'generic/platform=iOS' build`. Run tests. Commit — `Set the version, privacy manifest, and export answer for TestFlight`

### Task 5: Privacy page

**Files:** Create `docs/privacy.html`. Modify `docs/index.html` (footer link) and `HomeView.swift` (a quiet footer under All routes: "Not an official NYU app · Privacy", the second word linking to the page).

The page says, in plain words:
- **Location** is used on the phone to find the nearest stop and time walks. When you search or plan a trip, Apple Maps receives the places involved to return results and walking routes. Bussin's maker never receives or stores your location.
- **Usage counts** go to PostHog: that the app was opened, which routes, stops, and buses were viewed, and for a planned trip the route and the two stops. Never a searched address, a place name, or coordinates. No account, name, or email.
- **Favorites and recent searches** stay on the phone.
- **Bus positions** come from NYU's Passio GO feed. Bussin is a student project and is not affiliated with NYU or Passio.
- **Contact:** an email address Chris chooses (needed before this page is published; it is also the feedback address Apple asks for).

- [ ] Write the page in the product page's existing style, run it through the humanize rules, check it at phone width. Commit — `Add a privacy page`. It goes live on GitHub Pages when main is pushed.

### Task 6: Upload to TestFlight

- [ ] **Chris, in App Store Connect** (appstoreconnect.apple.com → Apps → +):
  1. New App: platform iOS, name "Bussin" (if taken, "Bussin: NYU Shuttles"), language English (U.S.), bundle ID `com.schwaigs.bussin`, SKU `bussin`.
  2. Tell Claude when it exists.
- [ ] **Claude:** archive and upload using the Apple account already in Xcode:

```bash
cd ios && xcodebuild -project Bussin.xcodeproj -scheme Bussin -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Bussin.xcarchive -allowProvisioningUpdates archive
```

  then `xcodebuild -exportArchive` with an export options file using method `app-store-connect` and destination `upload`. If the upload step can't authenticate from the command line, Chris uploads the same archive from Xcode's Organizer window (Window → Organizer → Distribute App → TestFlight & App Store).
- [ ] **Chris, once the build shows as processed** (about 10–30 minutes after upload):
  1. TestFlight tab → Test Information: paste the beta description and "what to test" text Claude drafts, the feedback email, and the privacy page URL.
  2. Create an External Testing group, add the build, and submit for Beta App Review.
  3. After approval, turn on the public link and copy it.
- [ ] Claude adds the link to the product page's "Try it" button and to `CLAUDE.md`.

### Task 7: Wrap up

- [ ] Full test run. Install the same build on Chris's iPhone.
- [ ] Update `CLAUDE.md`, `build-map.html` (republish), and the spec's open-items list (Developer Program done, logo provisional).
- [ ] Fill in the Build 3 log in `docs/index.html` (due Nov 23): the core workflow works end to end with real inputs, plus the funnel events. Chris supplies cost and hours.
- [ ] Finish the branch with superpowers:finishing-a-development-branch.

## What could go wrong

- **Apple rejects the beta.** Likeliest reasons: the app looking like an official NYU or MTA product, or the privacy URL missing. The "not an official NYU app" lines and the privacy page are there for this.
- **The name "Bussin" is taken** on the App Store. The fallback name is in Task 6. The name on the phone's home screen stays "Bussin" either way.
- **The feed gets blocked** after the link is public. The app then shows the "Can't reach live bus data" notice from Task 2 instead of an empty map.
