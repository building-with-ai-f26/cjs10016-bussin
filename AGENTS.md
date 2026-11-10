# AGENTS.md — Coding Agent Operating Manual

> Give this file to your coding agent and check that it is using these instructions. Keep the stack, commands, and ground rules current.

## 1. Project Overview
- **What this repo builds:** Bussin, a native iOS app (SwiftUI + MapKit) that shows NYU's free shuttles live and plans trips on them. An interactive HTML prototype lives in `docs/prototype/` and the product page/PRD in `docs/index.html`. Product truth is in `PRODUCT.md`; the visual system is in `DESIGN.md`.
- **Primary user & core workflow:** NYU students; see the living PRD in `docs/index.html`.
- **Tech stack:** Swift / SwiftUI / MapKit, XcodeGen, XCTest, Passio GO public feed (no auth), PostHog (optional, key in `ios/Secrets.xcconfig`), GitHub Pages for the prototype. Ridership logging runs separately in the `bussin-data` repo.

## 2. Commands
- **Install dependencies:** `brew install xcodegen` (the PostHog package resolves automatically)
- **Generate the Xcode project:** `cd ios && xcodegen generate` (run after any `project.yml` change or file add/remove; `ios/Bussin.xcodeproj` is gitignored)
- **Run locally:** open `ios/Bussin.xcodeproj` in Xcode and hit Run, or `xcodebuild -project ios/Bussin.xcodeproj -scheme Bussin -destination 'platform=iOS Simulator,name=iPhone 17' build`
- **Run deterministic tests:** `xcodebuild test -project ios/Bussin.xcodeproj -scheme Bussin -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Prototype:** `python3 -m http.server 8000 --directory docs` then open http://localhost:8000/prototype/

## 3. Non-Negotiable Engineering Rules
1. **Plan before coding:** Before touching multiple files, propose a brief plan and wait for approval.
2. **Small batches:** Make small, focused changes that can be reviewed and explained by a human in a single Pull Request.
3. **Explainability:** Avoid unnecessary abstractions or dependencies. Help the human builder understand the main components, what changed, why it matters, what could break, and how it was checked.
4. **Verify changes:** Run relevant checks. For a reproducible logic bug, use a failing test to demonstrate the fix when practical. Record manual checks and known limitations; follow the selected Build 4 evaluation track.
5. **Zero secrets in code:** Never hardcode API keys, tokens, or credentials. Always read from environment variables (`.env`) and update `.env.example` when new variables are needed.
6. **Stop when looping:** If a fix fails twice in a row, stop, summarize what failed, and ask the human before trying a third approach.
