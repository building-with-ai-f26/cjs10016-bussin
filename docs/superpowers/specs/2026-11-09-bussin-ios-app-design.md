# Bussin iOS app — design

Date: 2026-11-09. Status: approved in conversation, pending final read.

## What we're building

The native iOS version of Bussin: live NYU shuttle positions on Apple Maps, real arrival times at every stop, and a trip planner that compares shuttles against walking. It replaces the HTML prototype at `docs/prototype/`, which stays up as the design reference — the iOS screens copy it.

Chris wants to move faster than the class calendar: get it on his own phone as soon as the planner works, then make it shareable through TestFlight. Class deliverables (Build 2 on Nov 16 needs the smallest local version plus PostHog; Build 5 needs a shareable build; the sponsor memo is due Dec 14) get logged as we pass them, not waited for.

## Approach

Pure SwiftUI with the modern MapKit `Map` API, iOS 18 minimum, Xcode 27.2. No third-party dependencies except the PostHog SDK. One escape hatch, decided against only if needed: if bus markers look jumpy or follow-the-bus feels rough, we wrap just the map view in UIKit's `MKMapView` and leave the rest of the app alone.

Project lives at `ios/Bussin.xcodeproj` with sources in `ios/Bussin/`. Bundle id `com.schwaigs.bussin`, display name "Bussin".

## Data layer

- **PassioAPI** — a small client for the three endpoints the prototype already uses: `getStops`, `getRoutes`, `getBuses` on `passio3.com/www/mapGetData.php`, NYU system 1007. No auth.
- **ShuttleStore** — the app's single source of truth, an `@Observable` object. On launch it loads routes and stops from the network, falling back to a bundled snapshot (the one in `tools/prototype/data/`) so first launch works with no signal. It polls live buses every 4 seconds, pauses when the app backgrounds, and marks buses stale when the feed goes quiet for 30 seconds.
- **Route filter** — NYU's Passio system also carries commuter routes and ferries ("Manhattan Park Ave.", "Brooklyn"). V1 shows only the seven lettered shuttle routes (A, B, C, E, F, G, W), matching the prototype. The feed's `excludedRoutesID` field tells us which are off (W on weekdays, for example).
- **LocationService** — CoreLocation, when-in-use permission. If denied, everything still works with distances measured from 715 Broadway.

## The math

Two pure-Swift modules, no UI imports, fully unit-tested:

- **ETAEngine** — ports the prototype's distance-along-route model to real positions: snap each bus's GPS point onto its route polyline, compute distance along the route, and an ETA to any stop is remaining distance divided by speed. Speed starts at the fixed ~4 m/s average and corrects itself from how far each bus actually moved between pings. Loop routes wrap around; the engine handles the modulo.
- **TripPlanner** — direct port of the prototype's `plan()`: for each running route, the best board/alight stop pair, with walking legs estimated as straight-line distance × 1.25 detour at 1.3 m/s. Compared against walking the whole way. Real MapKit walking directions are a later polish for the selected option only.

## Screens

Apple Maps base with route polylines, stop dots, live bus markers, and the user's location. A bottom sheet using native `presentationDetents` (three heights, map touchable behind it — the Apple Maps pattern). Inside the sheet, a navigation stack with the screens the prototype already proved out: Home (nearest stop departures, favorites, all routes), Search → Trip plan, Stop detail, Route detail, and Bus detail (upcoming stops with times, follow-the-bus).

Search runs against the curated NYU destinations list first; `MKLocalSearch` for arbitrary places is a later add.

## Ridership data (for the NYU route pitch)

Passio's bus feed includes `paxLoad` (riders aboard right now) and `totalCap` per bus — confirmed live on Nov 9 (a Route A bus reporting 56 of 64). Three pieces:

1. **Collector** — a GitHub Action on a 15-minute cron that polls `getBuses` and appends one line per bus (timestamp, route, riders, capacity, lat/lng) to a daily JSONL file. It lives in a separate small repo, `bussin-data`, so its commits don't flood the class repo. Starts in week 1; the data compounds daily and feeds the Dec 14 sponsor memo.
2. **App demand signals** — PostHog events: `route_viewed`, `trip_planned` (board/alight stops, route), and `no_good_option` when a search produces no shuttle better than walking. That last one measures unmet demand.
3. **Analysis** — a short Python script turning the JSONL into riders-by-route-by-hour-by-weekday charts for the NYU pitch.

Validation first: watch a week of collector output and sanity-check `paxLoad` against actual rides before building any argument on it. First find (Nov 10): a Route B bus reported its position as rural New Hampshire mid-service, so off-corridor filtering is required — a ping more than ~300 m from its route's own polyline (which the feed supplies) gets flagged. The ETA engine computes that projection distance anyway; the collector keeps raw rows and filters at analysis time, so glitch frequency itself becomes reportable.

## Feed extras banked for later

Probed the live feed on Nov 9; fields we aren't using yet but should remember:

- **Crowding indicator** — `paxLoad`/`totalCap` per bus means the app can say "28 of 64 aboard" or "nearly full, next one in 6 min." Strong future feature; no NYU tool shows it.
- **Automatic outage alerts** — `excludedRoutesID` lists routes Passio has suspended right now. Diffing it against the expected weekday/weekend pattern yields "Route C isn't running today" alerts with no human in the loop, under the hand-edited holiday JSON.
- **Boarding detection** — stops carry a 50 m `radius` geofence; matched with the nearest bus, the app can notice you've boarded. Feeds the Campus Safety report (auto-attach bus, route, location) and personal ride counts.
- **Real headings** — `calculatedCourse` orients bus arrows without inferring from movement.
- **Freshness** — `created` ping time plus the `outdated` flag give an honest "updated 4s ago" label and let us dim stale buses.
- **Passio's own ETAs** — an `eta=3&deviceId=…` endpoint returns their server-side predictions; useful to cross-check our ETAEngine during validation.
- Schedules exist server-side (`goShowSchedule: 1`) but the endpoint isn't obvious; guessed alert/schedule params returned nothing. Finding it means watching the official app's traffic. Parked.

## Alerts (roadmap phase)

Passio may not carry service alerts, so v1 alerts come from a JSON file we host on the existing GitHub Pages site. Chris edits the file ("No service Thanksgiving Nov 26–27"); the app fetches it at launch and shows a banner on the home screen and inside affected trip plans. Covers outages and holiday schedules with zero new infrastructure. A real alert source can replace the file later without changing the app's alert UI.

## Error handling

- Feed unreachable → banner saying live data is stale, last known buses stay on the map dimmed. Never a blank map.
- Malformed feed records → skip the record, keep the rest. Never crash on bad data.
- Retry with backoff; the 4-second poll loop survives individual failures.

## Testing

TDD on the pure logic: ETAEngine (projection accuracy, loop wrap-around, arrival ordering), TripPlanner (fixture snapshot in, known best option out), and `Decodable` models against recorded real-feed JSON (we already have snapshots). Screens get verified in the simulator; one launch smoke test guards against startup crashes.

## Secrets

PostHog's API key goes in a gitignored `Secrets.xcconfig`, with `Secrets.example.xcconfig` committed. Nothing else needs a key — Passio is public.

## Phases and model assignments

Chris asked to be told which Claude model to switch to at each phase boundary. The table is the contract; the session should announce switches.

| Phase | Ships | Start on | Mid-phase switch |
|---|---|---|---|
| 1 — Walking skeleton | Xcode project, models, PassioAPI, live buses + routes + stops on the real map, basic PostHog init, **ridership collector repo running** | Fable/Opus | — |
| 2 — ETAs + sheet | ETAEngine, bottom sheet, Home with real departures, Stop/Route/Bus detail screens | Fable/Opus (engine) | Sonnet once screens start |
| 3 — Trip planner + search | TripPlanner port, Search → Plan flow. **Goes on Chris's phone; daily use begins** | Fable/Opus (port) | Sonnet for search UI |
| 4 — Share-ready | App icon (blocked on logo pick), onboarding + location priming, error-state polish, TestFlight external beta, full PostHog funnels | Sonnet | Haiku for asset chores; Fable/Opus for build-log writing |
| 5 — Roadmap adds | Hosted-JSON service alerts, Campus Safety report button (after talking to Campus Safety), alternate station-lamp icon, ridership analysis for the NYU pitch | Sonnet | Fable/Opus for Campus Safety design |

Rule of thumb: architecture, math, and debugging on Fable or Opus; established-pattern screens on Sonnet; pure chores on Haiku; review each phase with a different top model than the one that wrote it.

## Open items and risks

- **Apple Developer Program** — Chris enrolls this week ($99/yr). Until it clears, phone installs use free 7-day signing.
- **Logo** — still three finalists (Mosaic, Station sign, Bus LED). Blocks the phase 4 app icon, nothing earlier.
- **Passio permission** — the feed is open but third-party use is unconfirmed. Standing risk; worth an email to NYU Transportation in parallel. The app is free and attributes the data source.
- **paxLoad quality** — unvalidated until the collector's first week of data checks out.
