# Bussin

> An iPhone app for NYU's free shuttle buses. It shows where your bus is, when it will reach your stop, and which shuttle gets you where you're going.

- **Builder:** Chris Schwaiger (`@schwaigs-cj`)
- **Pod:** [add pod]
- **Product page and living PRD:** https://building-with-ai-f26.github.io/cjs10016-bussin/
- **Interactive prototype:** https://building-with-ai-f26.github.io/cjs10016-bussin/prototype/ (works on a phone)
- **App:** a native iOS app in SwiftUI with Apple Maps, starting in Build 2. A cloud or TestFlight link comes in Build 5.

## Why

NYU students ride the shuttles for free, but Passio GO, the app NYU points them to, is close to unusable. It puts buses on a map, but it won't tell you how far the next bus is from your stop or when it will get there, and you can't type in a destination to find out which shuttle to take. Bussin answers those questions first.

## Where it stands (Nov 9, 2026)

- **Build 1 is done.** It includes PRD v1, a home screen mockup, and an interactive prototype that runs in the browser. You can search for a place like NYU Tandon, compare shuttle options against walking, and tap any stop or route. The routes and stops are real NYU data. The buses and arrival times are simulated.
- **Biggest finding so far:** Passio GO's live feed for NYU answers without a login, so bus positions are reachable. What I don't know yet is whether Passio allows a third-party app to use that feed. That's the riskiest open question.
- **Next, for Build 2 (due Nov 16):** the first SwiftUI version reading the real feed, plus PostHog analytics.
- **Logo:** four rounds of concepts are in [`logo/`](./logo/). Three finalists are left, all based on NYC signage, and I haven't picked one yet.

## Repository map

| Path | What it is |
| --- | --- |
| [`docs/index.html`](./docs/index.html) | Product page: the pitch, the living PRD, and the weekly build log. Published with GitHub Pages. |
| [`docs/prototype/`](./docs/prototype/) | The interactive prototype, a single self-contained HTML file. |
| [`docs/mockup/`](./docs/mockup/) | The first home screen mockup, kept for reference. |
| [`tools/prototype/`](./tools/prototype/) | Scripts and a Passio data snapshot that rebuild the prototype. See its README. |
| [`logo/`](./logo/) | Logo and app icon exploration, one page per round. |
| [`AGENTS.md`](./AGENTS.md) | Run commands, project context, and rules for the coding agent. |
| [`tests/`](./tests/) | Verification for Build 4. |
| [`SPONSOR_MEMO.md`](./SPONSOR_MEMO.md) | The final recommendation memo, due Dec 14. |
| [`Intent.md`](./Intent.md), [`Plan.md`](./Plan.md), [`journal/`](./journal/) | Optional drafting notes from the course template. |

## Run it locally

The prototype is static HTML with no dependencies.

```bash
git clone https://github.com/building-with-ai-f26/cjs10016-bussin.git
cd cjs10016-bussin
python3 -m http.server 8000 --directory docs
```

Then open http://localhost:8000/prototype/. Opening `docs/prototype/index.html` straight from Finder works too.

To change the prototype's map or route data, follow [`tools/prototype/README.md`](./tools/prototype/README.md). It covers re-downloading the street data and refreshing the Passio snapshot.

Instructions for the iOS app will go here and in `AGENTS.md` once the Xcode project exists. You'll need a Mac with Xcode.

## Keys and secrets

Nothing needs an API key yet. Passio's feed is public, and the prototype map is drawn from OpenStreetMap data. If that changes, keys go in a local `.env` file, which git ignores, and placeholders go in `.env.example`.

---

Built for *Building with AI* at NYU Stern, Fall 2026. Assignment instructions and submissions live on [Icerynk](https://www.icerynk.com/c/fa26-tech-gb-2160-dm2-f2/content). Map data © OpenStreetMap contributors.
