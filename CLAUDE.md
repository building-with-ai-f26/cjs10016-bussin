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

## Where things stand (Nov 11, 2026)

- **Phase 1 is merged.** This is the walking skeleton: live buses, routes, and stops on Apple Maps, with the Passio feed parsed and tested.
- **Phase 2 is merged.** It added ETAs and the four screens:
  - `RouteGeometry` measures distance along each route.
  - `BusTracker` smooths speed over about 120 seconds, so a red light doesn't swing every estimate, and drops GPS readings more than 300 m off the route.
  - `ETAEngine` turns that into arrival times.
  - The slide-up sheet has Home, Stop, Route, and Bus screens. The map focuses on whatever is open and follows the open bus.
  - 21 XCTests cover all of this.
- **PostHog is live.**
  - iOS reads its key from the gitignored `ios/Secrets.xcconfig`, which only exists on Chris's laptop. Analytics is off in any build without it. The app sends named events: `app_opened`, `route_viewed`, `stop_viewed`, and `bus_viewed`. Automatic screen tracking is off.
  - The product page carries the PostHog web snippet. Chris's Chrome has AdBlock, which blocks PostHog, so Chris tests the page with AdBlock paused.
- **Ridership collector.** It runs in a separate repo, `schwaigs-cj/bussin-data`. A GitHub Action logs riders aboard each bus every 15 minutes, which builds evidence for suggesting route changes to NYU.
- **Research.** Competitive research on Passio and its competitors is in `research/`.

## What's next

1. **Build 2 (due Nov 16).** Chris needs to screenshot the `$pageview` and `clicked_try_product` events in PostHog and fill in the hours in the Build 2 log in `docs/index.html`.
2. **Phase 3: trip planning.** Write the plan first.
   - Port the prototype's `plan()` function from `docs/prototype/`, which compares taking the shuttle against walking.
   - Add search over NYU destinations.
   - Install the app on Chris's iPhone.
   - Use Opus or Fable for the planner math and Sonnet for the search screen.
3. **Phase 4: share-ready.** Get the app ready for TestFlight. The app icon is blocked until Chris picks a logo: Mosaic, Station sign, or Bus LED.
4. **Phase 5: roadmap.**
   - Service alerts, including holiday schedules.
   - A Campus Safety report button.
   - Crowdsourced "ride mode."
   - Smarter ETAs from live traffic, then ML.
   - "Time to leave" notifications.
   - Alternate app icons.
   - The ridership pitch to NYU.

**Chris's own to-dos:**
- Enroll in the Apple Developer program.
- Pick the logo.
- Email NYU Transportation about permission to use the Passio feed. This is a standing risk.

## Quirks worth knowing

- **Simulator.**
  - In Xcode 27 the Simulator app is DeviceHub.app, inside `/Applications/Xcode.app/Contents/Applications/`.
  - `simctl privacy grant location` doesn't suppress the location prompt, so someone has to tap Allow once.
  - To open a specific screen for a screenshot: `xcrun simctl launch --terminate-running-process "iPhone 17" com.schwaigs.bussin -place route:74769` (or `stop:6545` or `bus:first`).
- **Passio feed.**
  - PHP returns `[]` where it means an empty `{}`.
  - Latitude and longitude arrive as strings.
  - NYU Langone commuter routes share the same system ID, so keep only the lettered routes.
  - Weekday and weekend snapshots differ: Route W runs on weekends only.
- **PostHog ignores headless browsers.** To test the web page with headless Chrome, override the user agent.
- **Cloud sessions run on Linux, which has no Xcode.** They can't build the app or run the XCTests. Use them for planning, docs, the product page, and reading code. Do builds and tests on Chris's Mac.
