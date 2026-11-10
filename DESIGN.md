---
name: Bussin
description: NYU shuttle tracking that reads like a native Apple app — the answer first, the interface second.
colors:
  system-blue: "#007aff"
  live-green: "#248a3d"
  alert-red: "#ff3b30"
  ink: "#000000"
  ink-secondary: "rgba(60, 60, 67, 0.72)"
  ink-tertiary: "rgba(60, 60, 67, 0.45)"
  separator: "rgba(60, 60, 67, 0.18)"
  fill-quiet: "rgba(118, 118, 128, 0.12)"
  card: "rgba(255, 255, 255, 0.85)"
  glass: "rgba(246, 246, 248, 0.8)"
  glass-border: "rgba(255, 255, 255, 0.7)"
  map-land: "#f4f2ed"
  map-water: "#a8d3f2"
  map-park: "#cde7bf"
typography:
  display:
    fontFamily: "-apple-system, 'SF Pro Text', 'Helvetica Neue', sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.015em"
  headline:
    fontFamily: "-apple-system, 'SF Pro Text', 'Helvetica Neue', sans-serif"
    fontSize: "20px"
    fontWeight: 700
    letterSpacing: "-0.01em"
  title:
    fontFamily: "-apple-system, 'SF Pro Text', 'Helvetica Neue', sans-serif"
    fontSize: "17px"
    fontWeight: 600
  body:
    fontFamily: "-apple-system, 'SF Pro Text', 'Helvetica Neue', sans-serif"
    fontSize: "17px"
    fontWeight: 400
  label:
    fontFamily: "-apple-system, 'SF Pro Text', 'Helvetica Neue', sans-serif"
    fontSize: "13px"
    fontWeight: 400
rounded:
  sheet: "40px"
  card: "22px"
  pill: "22px"
  badge-lg: "12px"
  badge: "8px"
  badge-sm: "6px"
  icon-tile: "11px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "14px"
  xl: "16px"
components:
  card:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.card}"
  row:
    height: "60px"
    padding: "8px 14px"
  route-badge:
    size: "30px"
    rounded: "{rounded.badge}"
  search-pill:
    backgroundColor: "{colors.fill-quiet}"
    height: "44px"
    rounded: "{rounded.pill}"
    padding: "0 14px"
  trip-option:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.card}"
    padding: "14px"
---

# Design System: Bussin

## Overview

**Creative North Star: "Glance and Go"**

Every screen is designed to be read in two seconds by someone walking to a stop. The product's one job — where's my bus, when, which one — sets the hierarchy on every surface: the answer is the biggest, most colorful thing in view, and everything else recedes. Components are calm and factual; the data (route letters, arrival times, the live green pulse) is the only decoration the system allows itself.

The visual language is borrowed deliberately from Apple Maps and the iOS system palette: translucent glass surfaces over a soft map, semantic grays for text, one blue for interaction, cards inside a detent sheet. Bussin's own identity lives in content — NYU's seven route colors (supplied by the Passio feed, not by this file), New York place names, and the NYC-signage brand direction (see PRODUCT.md) — never in reinvented chrome. This system was captured from the HTML prototype (`docs/prototype/`); the iOS app translates each token to its native equivalent (SF text styles, system materials, semantic colors) rather than hardcoding these literals.

**Key Characteristics:**
- Answer-first hierarchy: times and route letters outrank titles and controls.
- Apple's materials and manners; NYU's content and color.
- Dual-appearance from birth: every token has a light and dark value.
- Data colors are functional, never ornamental.

## Colors

An iOS-semantic neutral ramp with exactly three voices of accent — blue speaks for interaction, green for live data, red for alerts — over a muted cartographic ground.

### Primary
- **System Blue** (#007aff · dark #0a84ff): interactive elements only — links, buttons, the user's location dot, the selected trip's border, the hub stop tile. Never decoration.

### Secondary
- **Live Green** (#248a3d · dark #30d158): owns exactly one meaning — "this is live data." Arrival countdowns, the radio-wave live icon, "Leave now." Nothing else may be this green.
- **Alert Red** (#ff3b30 · dark #ff453a): destination pins, the arrival flag, and (future) service alerts.

### Tertiary
- **Route colors** (data-driven): each route's color arrives from the Passio feed at runtime (Route A pink #f7b6d2, B violet #9370DB, E brick #CD5C5C, …) and matches NYU's own signage. Text on a route color is black or white by computed luminance (threshold 0.6). These are content, not theme: they color badges, polylines, bus markers, and timeline rails, and nothing that isn't that route.

### Neutral
- **Ink** (#000000 · dark #ffffff): primary text.
- **Ink Secondary** (rgba(60,60,67,0.72) · dark rgba(235,235,245,0.68)): subtitles, metadata, "then 12 min."
- **Ink Tertiary** (rgba(60,60,67,0.45) · dark rgba(235,235,245,0.4)): chevrons, the sheet grabber.
- **Separator** (rgba(60,60,67,0.18) · dark rgba(84,84,88,0.6)): hairline row dividers, inset 56px from the left so icons sit in a clean column.
- **Fill Quiet** (rgba(118,118,128,0.12) · dark 0.24): search field, segmented controls, placeholder icon tiles.
- **Card** (rgba(255,255,255,0.85) · dark rgba(58,58,60,0.62)) and **Glass** (rgba(246,246,248,0.8) · dark rgba(36,36,38,0.78)): the two surface materials (see Elevation & Depth).
- **Map ground**: land #f4f2ed, water #a8d3f2, park #cde7bf (dark: #2a2a2c / #1b3550 / #233a27) — desaturated so route colors and markers carry the figure-ground contrast.

### Named Rules
**The Three Voices Rule.** Blue is interaction, green is live, red is alert. No fourth accent may be introduced, and none of the three may borrow another's meaning.

**The Feed Owns Route Colors Rule.** Route colors are runtime data from Passio, matching NYU's printed signage. Never restyle, "improve," or hardcode them into the theme; always compute text contrast per color.

## Typography

**Display Font:** SF Pro (system: -apple-system / SF Pro Text, Helvetica Neue fallback)
**Body Font:** same — one family carries the entire app.

**Character:** Pure San Francisco, tight tracking on large sizes, weight doing the hierarchy work. Nothing typographically "branded" inside the app; the brand face (NYC-signage lettering) lives in the logo and marketing, never in the UI.

### Hierarchy
- **Display** (700, 24px, 1.15, −0.015em): sheet-header titles — the stop, route, or destination name.
- **Headline** (700, 20px, −0.01em): section headers inside sheets ("Nearest Stop", "Upcoming stops").
- **Title** (600, 17px): row primary text and emphasized values; the regular-weight (400) sibling is used where rows are plentiful and calm matters.
- **Body** (400, 15–17px): descriptive text, secondary clauses.
- **Label** (400–600, 13px; 11–12px floor in badges/markers): metadata, ETAs' second line, marker letters (always 700 in markers).
- **Numbers that answer** (600–700, 17–22px, green when live): arrival minutes and totals get title-or-larger size regardless of where they sit.

### Named Rules
**The Answer Is Biggest Rule.** On any screen, the largest text after the title must be the number or word the rider came for. If a label outranks an answer, the hierarchy is wrong.

## Layout

A single-column sheet over a full-bleed map. Content lives in cards (22px radius) inside a bottom sheet with three detents (peek ≈132px, medium ≈52% of height, large = full minus safe area); the map stays interactive behind every detent. Sheet content padding 16px; rows are ≥60px tall with 8/14px internal padding; the spacing rhythm is 4/8/12/14/16. Touch targets never fall below 44×44pt. Favorites use a 4-across grid of 56px circles. On iOS this translates to a native sheet with `presentationDetents` and inset-grouped-style cards; safe-area insets are respected top and bottom.

## Elevation & Depth

Depth is conveyed by material, not shadow stacking: translucent surfaces (glass at 28px blur, 180% saturation in the prototype; system materials on iOS) separate the UI layer from the living map behind it. Exactly one ambient shadow token exists for floating surfaces (`0 10px 40px rgba(0,0,0,0.14), 0 1px 3px rgba(0,0,0,0.08)`; heavier in dark mode), plus a small crisp drop (`0 2px 5px rgba(0,0,0,0.35)`) under map markers so they sit *on* the map rather than in it.

### Named Rules
**The One Shadow Rule.** Floating UI gets the ambient token; markers get the marker drop; nothing else casts anything. If a surface needs more separation, it wants material or hierarchy, not a bigger shadow.

## Shapes

Concentric rounding, Apple-style: the sheet (40px) wraps cards (22px) wraps controls (22px pills, 8–12px badges). Circles mean "a thing on the map or a person" — bus markers (26px), stop dots (10px with 2px ring), favorites (56px), avatars (44px). Rounded squares mean "a place or a route" — route badges (30px at 8px radius; 44px at 12px in headers; 24px at 6px inline), the hub-stop tile (30px at 8px). Hairline borders are rings on markers (white, 2–2.5px) and nothing else; cards are borderless, separated by background contrast alone.

## Components

### Bottom Sheet
- Calm glass surface, 40px top radius, 36×5px grabber in Ink Tertiary.
- Three detents; drag anywhere on the header zone; content scrolls only at full height.
- The map behind it never deactivates.

### Cards / Containers
- **Corner:** 22px. **Background:** Card material. **Border:** none. **Shadow:** none (the sheet carries elevation).
- Rows inside: 60px min height, hairline separators inset 56px, chevron in Ink Tertiary on navigable rows.

### Route Badge
- Rounded square filled with the route's feed color; route letter in SF 700, black or white by luminance.
- Sizes: 24px/6px inline · 30px/8px rows · 44px/12px headers. Dimmed to 45% when the route isn't running.

### ETA Column
- Right-aligned, two lines: live line first (17px/600, Live Green, radio-wave icon, "Now" under 45s), then "then N min" (13px, Ink Secondary).

### Search Pill
- 44px pill in Fill Quiet; magnifier + placeholder "Where to?" in Ink Secondary; mic trailing. Becomes a focused input inline (no separate screen chrome).

### Bus Marker
- 26px circle in route color, 2.5px white ring, route letter, marker drop shadow; heading arrow orbits outside the ring; 4s-cadence position updates animate smoothly (no teleporting). Dims to 20% when another route is focused; selected bus enlarges to 34px with a blue halo.

### Trip Option Card
- Card with legs summary (walk → badge → walk), total minutes 22px/700 right-aligned, "Leave in N min" in Live Green; selected state = 2px System Blue border; expanded state reveals a step list.

### Timeline (route/bus detail)
- 6px rail in route color, 16px white dots with 4px route-color ring; bus chips (24px circles) sit between stops at their live position.

### Live Icon (signature)
- A dot with two radiating arcs, pulsing in sequence (1.8s loop, 0.3s stagger) — the system's one piece of motion-as-meaning; always Live Green, always next to a live number.

## Do's and Don'ts

### Do:
- **Do** put the rider's answer (minutes, route letter) in the largest, most colorful position on every new screen — the Two-Second test: hand the screen to someone walking, count to two, they know what to do.
- **Do** design light and dark together; every new color needs both values the day it's born.
- **Do** translate to native equivalents in SwiftUI: SF text styles, system materials, `Color(.label)`-family semantics, SF Symbols — these keep the future accessibility retrofit cheap (PRODUCT.md).
- **Do** label data honesty states: simulated, stale ("updated 40s ago"), and estimated values say so in Ink Secondary.
- **Do** keep 44pt touch targets even on dense timeline rows.

### Don't:
- **Don't** reproduce Passio GO's patterns: no dense menus, banner clutter, unlabeled tiny buses, or vendor-generic styling. It is the anti-reference.
- **Don't** let the app read as a wrapped website — no hover-dependent affordances, hamburger menus, custom back controls, or web-shaped buttons.
- **Don't** gamify: no streaks, badges, confetti, or mascots, even in growth features.
- **Don't** introduce a fourth accent color or use route colors decoratively outside their route.
- **Don't** hardcode feed-supplied route colors into themes or assets.
