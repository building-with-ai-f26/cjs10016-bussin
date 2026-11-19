# CLAUDE.md

@AGENTS.md

This file holds the working agreements and current state that used to live only in Claude's local memory, so that a fresh session or a cloud session can pick up the build. Product truth lives in `PRODUCT.md`, the visual system in `DESIGN.md`, and the full design spec in `docs/superpowers/specs/2026-11-09-bussin-ios-app-design.md`.

## How Chris likes to work

- **Humanize all writing.** Commit messages, the product page, the PRD, build logs, and graded writing all go through the humanize skill. If the skill isn't installed, the rules still hold: plain, specific language, a clear stance, and none of the usual AI tells.
- **Plain language.** Chris isn't deeply technical. Say what changed and why it matters for a rider before giving implementation detail.
- **Build map.** The visual progress tracker is published at https://claude.ai/artifact/HuJaUrSyGzp4B8iSeywM74. Its source is `build-map.html` in the repo root. After every completed build step, update that file and republish it to the same artifact URL. Use non-technical wording, and tag every step with the model to use.
- **Model reminders.** At the start of each phase, remind Chris which model to switch to:
  - Fable or Opus for math, the engine, and debugging.
  - Sonnet for screens.
  - Haiku for chores.
  - Fable or Opus for graded writing.
- **Pace.** Chris builds ahead of the class calendar and logs each class build in `docs/index.html` before it is due.
- **Workflow.** Use the superpowers flow: brainstorm, then write a plan in `docs/superpowers/plans/`, then execute it inline, then finish the branch. Run tests before claiming anything works.

## Where things stand (Nov 17, 2026)

- **Phase 1 is merged.** This is the walking skeleton: live buses, routes, and stops on Apple Maps, with the Passio feed parsed and tested.
- **Phase 2 is merged.** It added ETAs and the four screens:
  - `RouteGeometry` measures distance along each route.
  - `BusTracker` smooths speed over about 120 seconds, so a red light doesn't swing every estimate, and drops GPS readings more than 300 m off the route.
  - `ETAEngine` turns that into arrival times.
  - The slide-up sheet has Home, Stop, Route, and Bus screens. The map focuses on whatever is open and follows the open bus.
  - 21 XCTests cover all of this.
- **Phase 3 is merged.** It added trip planning and put the app on Chris's iPhone:
  - Search any address or place through Apple Maps (`PlaceSearch`).
  - `TripPlanner` compares each running shuttle against walking. It shortlists stops with straight-line estimates, then re-times them with real Apple Maps walking routes from `WalkTimes` (at most 9 requests per trip, cached).
  - Favorites and the two latest searches sit on Home (`SavedPlaces`, stored on the phone).
  - Analytics send `trip_planned` and `no_good_option`, never the searched address.
  - Buses slide between feed updates (`GlidingMarker`). Home starts with the search row and shows the truly nearest stop, plus the nearest stop with a bus running when they differ.
  - 46 XCTests passed at the end of Phase 3 and 4; 48 after Phase 4b.
  - Installed on Chris's iPhone on Nov 11 signed with Chris's paid Apple Developer team. The signing profile runs until Nov 12, 2027. The team ID lives in `ios/Secrets.xcconfig` as `DEVELOPMENT_TEAM`. To reinstall: build with `-destination 'id=<phone UDID>' -allowProvisioningUpdates`, then `xcrun devicectl device install app`.
- **PostHog is live.**
  - iOS reads its key from the gitignored `ios/Secrets.xcconfig`, which only exists on Chris's laptop. Analytics is off in any build without it. The app sends named events: `app_opened`, `route_viewed`, `stop_viewed`, and `bus_viewed`. Automatic screen tracking is off.
  - Every app event carries `app_environment` (`debug` for Xcode and simulator runs, `release` for TestFlight). Filter on it to leave Chris's own testing out of charts. The name `build` is taken by PostHog, and `$is_testflight` can't be used for this because Xcode installs on a phone report as TestFlight too.
  - The "Bussin metrics" dashboard (PostHog project 721533, dashboard 2366469) holds the funnel, trip outcomes, location permission, routes viewed, retention, product page visits, and daily users.
  - The product page carries the PostHog web snippet. Chris's Chrome has AdBlock, which blocks PostHog, so Chris tests the page with AdBlock paused.
- **Ridership collector.** It runs in a separate repo, `schwaigs-cj/bussin-data`. A GitHub Action logs riders aboard each bus every 15 minutes, which builds evidence for suggesting route changes to NYU.
- **Research.** Competitive research on Passio and its competitors is in `research/`.

## What's next

1. **Build 2 log.** Hours, the NYU email status (not sent as of Nov 17), and Build 3's "what broke so far" are filled in. One placeholder is left: the PostHog screenshots (pageview, click on "See the Product", a session recording), after a test visit with AdBlock paused.
   - **Phase 4b: UI refresh (Nov 17).** Plan: `docs/superpowers/plans/2026-11-17-ios-phase-4b-ui-refresh.md`. Batch 1 (map feel) is merged: pinch-zoom no longer snaps back to an open bus, tapping the map shrinks the panel and tapping the panel restores it, the panel is the system Liquid Glass sheet on iOS 26+, and the app opens dark with a Light switch on Home (`Appearance`). The zoom fix still needs a check on Chris's phone with a moving bus.
   - **Go mode** (plan: `docs/superpowers/plans/2026-11-19-ios-go-mode.md`). Part 1, the trip highlight, is merged. Part 2a, Go inside the app, is built: `TripSession` (pure step logic, tested by replayed trips) and `GoTrip` (runs it every 2 s, buzzes, words each step), `GoView`, a Go button under the chosen option, and a "Trip in progress" row on Home. Boarding and the get-off alert are tested but not yet seen on a real ride. Part 2b, pocket mode, is built: during a trip only, `LocationAccess.beginTripTracking` keeps location on with the screen off (`CLBackgroundActivitySession`, "location" background mode, blue pill); `GoLiveCard` runs the Live Activity from the `BussinLiveActivity` widget extension (bundle ID `com.schwaigs.bussin.LiveActivity`, shared code in `ios/Shared/`), wakes the screen with an alert at "get off next", and falls back to a notification if Live Activities are off. Debug builds take `-goAlertTest YES` to fake the get-off alert 8 s after Go. The real buzz and background behavior still need a ride on Chris's phone. A TestFlight build with this needs a new build number and goes through beta review again.
   - **Slower shuttles (Nov 19).** On walks of 10+ minutes the planner offers a shuttle up to 10 minutes slower than walking (`maxSlowerThanWalking`, `slowerShuttleNeedsWalk`); walking stays the recommendation and the trip screen lists it first. Analytics still sends `no_good_option` for these (with `slower_shuttle_minutes`).
   - **Bus arrows (Nov 19).** Passio's `calculatedCourse` was within 30° of the road only 2 times in 14, so arrows now come from the route: `RouteGeometry.direction(at:)`. About half of Route F and a third of Route A run both ways along the same street, so `BusTracker` keeps every nearby match (`projections`) and picks the side by which way the bus moved (15 m or more); a parked bus keeps its side, and an unsure bus shows no arrow. This also fixes arrival times on those stretches. `LiveBus.headingDegrees` is no longer drawn.
   - **Trip starting point (Nov 19).** The trip screen has a From row (`TripView.from`, shared with the map as `MapScreen.tripFrom`); `SearchView` has a pick mode (`onPick`) for it, which skips recents. A different trip resets it. Go shows only within 200 m of the starting point (`TripView.goReady`). Analytics: `trip_origin_changed` with the source, never the place. During Go the map keeps the dotted walks and shows a compass beam from the blue dot (`LocationAccess.heading`, on only during a trip). After Go: bus arrows that follow the road (Fable/Opus), then trip planning (start anywhere, arrive by, every upcoming bus at a stop), then prototype address search.
2. **Ride-test Phase 3.** Chris rides with the app for a day. Still unseen with real buses: a daytime trip where a shuttle beats walking, smooth bus movement, and the "bus is at your stop" note.
   - A bus waiting at your boarding stop: if you're within a minute's walk the planner boards it; from further away it quotes the next sure bus and adds a "may leave without you" note. The app has no timetable, so it can't say when a waiting bus departs. Not yet seen live in the simulator, only in tests.
3. **Phase 4: share-ready.** The app side is done (welcome card, notices, funnel events, privacy page, release settings, dashboard). TestFlight is in Apple's hands:
   - Build 1.0.0 (1) was uploaded on Nov 17 and submitted for Beta App Review the same day, in the **external** TestFlight group "NYU Riders". Status: waiting for review (usually under a day, sometimes two).
   - The App Store Connect name is **Bussin Transit** because "Bussin" was taken. The name under the icon on a phone is still "Bussin". The name can change later without a new build.
   - There is also an internal group called "NYU Riders". It can't carry a public link, so ignore it.
   - Test Information, feedback email (supported.application@gmail.com), privacy URL, and review notes are filled in in App Store Connect.
   - **When Apple approves:** Chris opens the external group, turns on Public Link, and sends me the link. I paste it into `BETA_LINK` at the bottom of `docs/index.html` (the "Try the beta" button is built and stays hidden until that is set), then update this file and the build map.
   - **If Apple rejects:** the email says what to fix. A new build needs a higher `CURRENT_PROJECT_VERSION` in `ios/project.yml` (it is 1 now), then `xcodegen generate`, then archive: `cd ios && xcodebuild -project Bussin.xcodeproj -scheme Bussin -configuration Release -destination 'generic/platform=iOS' -archivePath build/Bussin.xcarchive -allowProvisioningUpdates archive`, then `xcodebuild -exportArchive` with an export options plist (method app-store-connect, destination upload, the team ID). That upload path worked on Nov 17.
   - The app uses the Station sign icon for now (Chris's pick on Nov 12, may change). `swift tools/make-app-icon.swift` redraws it. The final icon still needs rebuilding as layers in Apple's Icon Composer.
4. **Phase 5: roadmap.**
   - Service alerts, including holiday schedules.
   - A Campus Safety report button.
   - Crowdsourced "ride mode."
   - Smarter ETAs from live traffic, then ML.
   - "Time to leave" notifications.
   - Alternate app icons.
   - The ridership pitch to NYU.

**Chris's own to-dos:**
- Confirm the final logo. Station sign is in use for now; Mosaic and Bus LED are still options.
- Email NYU Transportation about permission to use the Passio feed. This is a standing risk.

## Quirks worth knowing

- **Simulator.**
  - In Xcode 27 the Simulator app is DeviceHub.app, inside `/Applications/Xcode.app/Contents/Applications/`.
  - `simctl privacy grant location` doesn't suppress the location prompt, so someone has to tap Allow once.
  - To open a specific screen for a screenshot: `xcrun simctl launch --terminate-running-process "iPhone 17" com.schwaigs.bussin -place route:74769` (or `stop:6545` or `bus:first`, `search`, or `trip:40.6943,-73.9865`).
- **Passio feed.**
  - PHP returns `[]` where it means an empty `{}`.
  - Latitude and longitude arrive as strings.
  - NYU Langone commuter routes share the same system ID, so keep only the lettered routes.
  - Weekday and weekend snapshots differ: Route W runs on weekends only.
- **PostHog ignores headless browsers.** To test the web page with headless Chrome, override the user agent.
- **Cloud sessions run on Linux, which has no Xcode.** They can't build the app or run the XCTests. Use them for planning, docs, the product page, and reading code. Do builds and tests on Chris's Mac.
