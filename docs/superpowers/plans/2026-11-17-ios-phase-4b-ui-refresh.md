# Phase 4b: UI refresh (Nov 17, 2026)

Chris's feedback after riding with the app, split into four batches. Each batch is its own branch and pull request. Run the tests before every commit.

## Decisions Chris made (Nov 17)
- **Map tap:** tapping the map shrinks the panel to its smallest height. Tapping the shrunk panel brings it back to half height. Tapping the map again does nothing.
- **Upcoming buses:** shown on the stop screen. Tap a route on a stop to see every bus coming in the next hour, not just the next two.
- **Arrive by:** live buses only, up to about an hour ahead. Bussin has no timetable, so it doesn't promise anything further out.
- **Dark mode:** dark by default, with a Dark | Light switch on Home. (Apple's advice is to follow the phone's setting; a third "Match phone" choice is easy to add if Chris wants it.)
- **Order:** map feel, then bus arrows, then trip planning, then prototype search.

## Batch 1: Map feel (branch `map-feel`, Sonnet; done Nov 17)
- Pinch-zoom: while a bus is open the map re-centered on it every 4 seconds and undid the rider's zoom. It now stops following once the rider moves the map (`camera.positionedByUser`). Opening the bus again starts following again.
- Tap map to shrink the panel, tap the panel to restore it. Taps on or next to a stop or bus open that marker instead.
- Liquid Glass: on iOS 26 and later the panel is the system glass sheet (the `.regularMaterial` override is gone there). The "can't reach live data" capsule is glass too. iOS 18 to 25 keep the frosted look.
- Dark by default, Light switch at the bottom of Home (`Appearance`, saved under the key `appearance`).

## Batch 2: Bus arrows (Fable or Opus)
- Today the arrow is Passio's `calculatedCourse`, unchecked. On Nov 17 it pointed across the road (bus B on a north-south street, arrow pointing west).
- First compare Passio's course with the route direction for live buses to confirm. Then a failing test, then add a "which way does the route run here" lookup to `RouteGeometry`, and point each arrow along its route. Fall back to Passio only when a bus is off its route.

## Batch 3: Trip planning (Fable or Opus for the planner, Sonnet for screens)
- A "From" field on the trip screen: current location by default, or any searched place.
- Arrive by: pick a time up to about an hour ahead, list the shuttle options that make it, and say when to leave.
- Stop screen: expand a route to see every bus due in the next hour.

## Batch 4: Prototype search (Sonnet)
- The web prototype's search only knows a fixed list of NYU places. Either add real address search (Photon, a free OpenStreetMap search service, limited to NYC, with a note that typed text goes to that service) or say plainly that only the app searches any address. Edit `tools/prototype/proto_template.html` and rebuild.

## Later ideas from the SwiftUI review (twostraws "swiftui-pro" skill)
- Respect Reduce Motion (bus sliding, camera moves, the pulsing live icon).
- Clock times use a fixed "h:mm", so 24-hour phones show the wrong format.
- Empty search results show a blank panel; use `ContentUnavailableView`.
- Mark the chosen trip option with a checkmark, not only a tint.
- Move the trip planner out of the views that redraw every 4 seconds (battery).
