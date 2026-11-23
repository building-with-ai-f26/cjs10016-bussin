# Security audit: Bussin

Build 3, audited Nov 22, 2026. Beginner lane.

## What kind of app this is

**No AI and no database.** Bussin is an iPhone app (SwiftUI and MapKit) plus a static product page on GitHub Pages. It has no server, no accounts, no sign-in, and no database. It makes no AI calls. Favorites and recent searches are saved on the phone itself and never leave it.

What it talks to:

| Service | What for | Key? |
|---|---|---|
| Passio GO feed (`passio3.com`, HTTPS) | Shuttle routes, stops, and live bus positions | None. The feed is public. |
| Apple Maps (MapKit) | Place search and walking times | None. Apple signs the app, so there's no key. |
| PostHog (`us.i.posthog.com`, HTTPS) | Usage counts in the app, page views and session replay on the website | The `phc_` project key, which is public by design and can only send events. |

Live URLs:
- Product page: https://building-with-ai-f26.github.io/cjs10016-bussin/
- iPhone beta: https://testflight.apple.com/join/qpmdUSEM (build 3 is live)

## What I checked

### 1. Access controls

With no AI and no database, the brief makes the secret-key search in step 2 the access test. With no accounts, there's no other user's data to reach. Everything a rider saves stays on their own phone.

### 2. Secret keys

I searched for `sb_secret_`, `service_role`, `sk-or-`, `sk-ant-`, `sk-proj-`, `sk_live_`, `ghp_`, `github_pat_`, and `AKIA`:

| Where | Result |
|---|---|
| Every file in the repo (`git grep`) | One match: `.env.example` held `sk-or-v1-replace-with-your-key`, a placeholder left over from the class template. It was never a real key. **Fixed:** I deleted the file, since Bussin doesn't use OpenRouter. |
| The full git history (`git log -p --all`) | The same placeholder line and nothing else. |
| The live site: `/`, `/privacy.html`, `/prototype/`, `/mockup/` | No matches. The only key on the page is the PostHog `phc_` key, which is meant to be public. |
| `ios/Secrets.xcconfig` (PostHog key and Apple team ID) | Gitignored and never committed. Only `ios/Secrets.example.xcconfig`, which holds placeholders, is in git. |

Nothing turned up that needed rotating.

### 3. File storage

Bussin stores no files and has no storage buckets.

### 4. Protecting production from the agent

- The "Ask me first" list in `AGENTS.md` covers deleting data, keys and secrets and permissions, and anything that costs money.
- The agent works on a branch, opens a pull request, and merges only when I say so. Merging to `main` is the only way the website changes.
- There's no database, so nothing needs backing up. The website is the git history: a bad deploy is undone by reverting the commit on `main`. A bad app build is undone in TestFlight by expiring that build, which leaves testers on the last good one.

### 5. Spending caps and rate limits

- **AI provider:** none, so there's no bill to cap.
- **PostHog:** free plan. *Still to confirm in PostHog's billing settings: that no card is on file, or that a $0 billing limit is set.* Without a card, PostHog stops counting past the free tier instead of charging.
- **Apple:** the $99/year developer fee is the only fixed cost. MapKit has no per-request fee. Apple throttles an app at about 50 walking-directions requests a minute. Bussin asks for at most 9 per trip and caches the answers.
- **Rate limits on routes:** Bussin has no routes of its own. No server takes requests and nothing writes to a database, so there's nothing for a visitor to flood.

### 6. Dependencies

There's no `npm` or `pip`. The app has one third-party package: PostHog's iOS SDK, version 3.94.3, through Swift Package Manager. Swift has no `npm audit`, so I checked GitHub's advisory database. It lists 64 Swift advisories, and none of them are for `posthog-ios`. The website and prototype load no packages beyond PostHog's own script.

### 7. Agent security review

I asked Claude Code to look for ways to break the app or leak data. Here is what it checked and found:

| What it tried | Result |
|---|---|
| Typing HTML or script into the prototype's search box | Safe. The search text goes through an `esc()` function before it reaches the page, both in the box and in the "No places match" message. |
| Opening hidden screens in the App Store build through the debug launch shortcuts (`-place`, `-goAlertTest`, `-resetWelcome`) | Safe. Every shortcut sits inside `#if DEBUG`, so release and TestFlight builds don't include them. |
| Linking into the app from outside | Nothing to attack. The app registers no URL scheme and no `onOpenURL` handler. |
| Feeding the app bad bus data | Handled. The parser has no `try!` or forced casts. A position more than 300 m off its route is dropped (one Route B bus once reported it was in New Hampshire). If the feed goes down, the app says "Can't reach live bus data" and keeps showing the last buses it saw. |
| Reading traffic on campus Wi-Fi | Safe. Every request is HTTPS, and there are no App Transport Security exceptions. |
| Finding where someone lives or goes from the analytics | Not possible. Events carry route and stop IDs but never a place name, an address, or coordinates. Session replay runs only on the website, not in the app. |
| Leaving location on in the background | **Fixed this week (PR 15, shipped in build 3).** Location used to keep running after you left the app. Now it stops the moment Bussin leaves the screen, unless a Go trip is running. A Go trip someone forgets about now ends 45 minutes after Go if they never board, or 30 minutes after they get off. Before, it could keep the blue location pill on for two hours. |

## What I fixed

1. Location no longer runs in the background except during a Go trip, and a forgotten trip ends on its own (PR 15, live in TestFlight build 3).
2. Deleted `.env.example` and its fake OpenRouter key, so a key scan comes back clean. I also updated the README line that pointed to it.

## Remaining issues

- **Passio permission (the biggest risk).** The feed is public, but nobody at Passio or NYU has said a third-party app may use it. I haven't sent that email yet. If they block the feed, the app shows no buses.
- **Load on Passio.** Each open phone asks Passio for bus positions every 4 seconds. A hundred riders at once is about 25 requests a second to a service I don't pay for. The fix would be a small relay server that asks Passio once and answers every phone. I haven't built it, because it would add the first server, and the first thing that needs securing.
- **The lock screen card shows your destination.** During Go, the card names where you're headed, so anyone who glances at your locked phone can see it. I'm leaving it because the card is meant to be glanced at. It ends when the trip ends.
- **The PostHog key can be misused.** Because the `phc_` key is public, anyone could send fake events into my dashboard. That would skew the numbers but can't read any data. Filtering on `app_environment = release` limits the damage.
- **The PostHog billing limit isn't confirmed yet** (see step 5).
