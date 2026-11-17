# AGENTS.md — Coding Agent Operating Manual

> Give this file to your coding agent and check that it is using these instructions. Keep the stack, commands, and ground rules current.

## 1. Project Overview
- **What this repo builds:** Bussin, a native iOS app (SwiftUI + MapKit) that shows NYU's free shuttles live and plans trips on them. An interactive HTML prototype lives in `docs/prototype/` and the product page/PRD in `docs/index.html`. Product truth is in `PRODUCT.md`; the visual system is in `DESIGN.md`.
- **Primary user & core workflow:** NYU students; see the living PRD in `docs/index.html`.
- **Tech stack:** Swift / SwiftUI / MapKit, XcodeGen, XCTest, Passio GO public feed (no auth), PostHog (optional, key in `ios/Secrets.xcconfig`), GitHub Pages for the prototype. Ridership logging runs separately in the `bussin-data` repo.

### Repo map
```
ios/                      the iPhone app
  project.yml             XcodeGen definition: targets, signing, Info.plist settings (source of truth)
  Config.xcconfig         default build settings, includes Secrets.xcconfig if present
  Secrets.example.xcconfig  template for the local secrets file (committed)
  Secrets.xcconfig        YOUR keys and Apple team ID (gitignored, never committed)
  Bussin/
    App/                  app entry point, Analytics.swift (all PostHog calls live here)
    Models/               pure logic, no UI: RouteGeometry, BusTracker, ETAEngine, TripPlanner, ServiceStatus
    Networking/           PassioAPI and the feed's payload types
    Store/                app state: ShuttleStore (feed polling), SavedPlaces, PlaceSearch, WalkTimes, LocationAccess
    Views/                SwiftUI screens: MapScreen, SheetHost, Home, Stop, Route, Bus, Search, Trip, Welcome
    Resources/            passio-stops.json, a bundled snapshot of routes and stops
  BussinTests/            XCTests, plus Fixtures/ with recorded real-feed JSON
docs/                     GitHub Pages site (published from main)
  index.html              product page, living PRD, weekly build log
  privacy.html            privacy page linked from the app
  prototype/, mockup/     the HTML prototype and first design mockup
  superpowers/specs|plans design spec and per-phase implementation plans
journal/                  optional per-build notes
research/                 competitor research on Passio
logo/                     logo exploration pages
tools/                    make-app-icon.swift (redraws the app icon), prototype build scripts
tests/                    notes on how verification works for this course
PRODUCT.md, DESIGN.md     what the product is, and the visual system
build-map.html            the visual progress tracker (published as a Claude artifact)
```
**How one screen of data gets there:** `ShuttleStore` polls the Passio feed every 4 seconds, `BusTracker` snaps each bus onto its route and learns its speed, `ETAEngine` turns that into arrival times, and the SwiftUI views read from the store. `TripPlanner` and `WalkTimes` answer "ride or walk?" for a searched place. Ridership logging is a separate repo, `bussin-data`, so its commits stay out of this history.

## 2. Commands
- **First-time setup (about 10 minutes):**
  1. Install Xcode and run `brew install xcodegen`. The PostHog package downloads by itself on first build.
  2. `cp ios/Secrets.example.xcconfig ios/Secrets.xcconfig`, then open the copy and replace the placeholder with your PostHog project key (`phc_...`). The app runs without it; analytics just stays off.
  3. To install on a real iPhone, add `DEVELOPMENT_TEAM = <your 10-character Apple team ID>` to the same file, sign in to your Apple ID in Xcode (Settings, then Accounts), and turn on Developer Mode on the phone (Settings, then Privacy & Security).
  4. `cd ios && xcodegen generate`
  5. Run the tests (below). All of them should pass without a PostHog key or a phone.
- **Run on a real iPhone:** plug it in, then `xcodebuild -project ios/Bussin.xcodeproj -scheme Bussin -destination 'id=<phone UDID>' -allowProvisioningUpdates build` and `xcrun devicectl device install app --device <phone UDID> <path to Bussin.app>`. Or pick the phone in Xcode and press Run.
- **Jump to a screen in the simulator (debug builds):** add launch arguments such as `-place route:74769`, `-place stop:6545`, `-place search`, `-place trip:40.6943,-73.9865`, or `-resetWelcome YES` to see the first-open card again.
- **Product page:** `python3 -m http.server 8000 --directory docs`, then open http://localhost:8000/. It also publishes automatically from `main` to https://building-with-ai-f26.github.io/cjs10016-bussin/.
- **Generate the Xcode project:** `cd ios && xcodegen generate` (run after any `project.yml` change or file add/remove; `ios/Bussin.xcodeproj` is gitignored)
- **Run locally:** open `ios/Bussin.xcodeproj` in Xcode and hit Run, or `xcodebuild -project ios/Bussin.xcodeproj -scheme Bussin -destination 'platform=iOS Simulator,name=iPhone 17' build`
- **Run deterministic tests:** `xcodebuild test -project ios/Bussin.xcodeproj -scheme Bussin -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Prototype:** `python3 -m http.server 8000 --directory docs` then open http://localhost:8000/prototype/

## 3. Non-Negotiable Engineering Rules
1. **Plan before coding:** Before touching multiple files, propose a brief plan and wait for approval.
2. **Small batches:** Make small, focused changes that can be reviewed and explained by a human in a single Pull Request.
3. **Explainability:** Avoid unnecessary abstractions or dependencies. Help the human builder understand the main components, what changed, why it matters, what could break, and how it was checked.
4. **Verify changes:** Run relevant checks. For a reproducible logic bug, use a failing test to demonstrate the fix when practical. Record manual checks and known limitations; follow the selected Build 4 evaluation track.
5. **Zero secrets in code:** Never hardcode API keys, tokens, or credentials. Keys and the Apple team ID live in the gitignored `ios/Secrets.xcconfig`, which feeds the build through `Config.xcconfig` and `project.yml`. When a new variable is needed, add a placeholder for it to `ios/Secrets.example.xcconfig`. (The PostHog project key is a public, write-only client key, which is why it also appears in the product page's script. Nothing else is allowed there.)
6. **Stop when looping:** If a fix fails twice in a row, stop, summarize what failed, and ask the human before trying a third approach.

## 4. Shipping
1. Run the tests before every commit.
2. Work on a branch. Open a pull request.
3. Merge only when the checks pass.
4. Merging to main deploys the site (the product page publishes from `docs/` on `main`).
5. Open the live URL. Check what you changed.
6. Tell me what is live, and what you checked.

## 5. Ask me first
- Deleting data or changing the database
- Keys, secrets and permissions
- Anything that costs money
