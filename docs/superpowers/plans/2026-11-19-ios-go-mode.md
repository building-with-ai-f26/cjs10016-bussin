# Go mode and the trip highlight (plan, Nov 19, 2026)

Chris's ask: pick a shuttle trip, tap **Go**, and Bussin tracks you live and tells you when to get off. Also, on a trip, highlight only the stretch of route you'll ride.

## Decisions
- **Alert:** a small lock screen card (a Live Activity, also in the Dynamic Island) plus a buzz when it's time to get off. Chris chose this on Nov 19.
- **Go covers the whole trip:** the walk to the stop, the ride, and the walk to the destination. It ends on its own when you arrive. (Default; Chris didn't pick.)
- **Highlight style:** the stretch you ride is thick and full color, and the rest of that route is the same color, faded. (Default.)
- **Order:** the highlight first, then Go, then the bus arrows batch. (Default.)

## Part 1: Trip highlight (one PR, small; Fable/Opus for the slicing, Sonnet for the map)
1. `RouteGeometry.coordinates(from:to:)` returns the stretch of route between two distances. On a loop that passes the end, it wraps around to the start. Tests come first: a plain stretch, a stretch that wraps on a loop, and the same start and end.
2. `MapScreen`: on a trip with a shuttle option picked, draw that route faded (about 30%), then the ride stretch on top, thicker and full color. The boarding and get-off stops get a bigger ring. Other routes stay dimmed as they are now.
3. Check in the simulator in dark and light mode, on a trip that wraps around a loop.

## Part 2a: Go, inside the app (one PR; Fable/Opus for the logic, Sonnet for the screen)
1. Each trip option records **which bus** it counts on (`busId`). The planner already knows this while it does the math; it just isn't saved. Test first.
2. `TripSession` is a new piece of pure logic with no UI, so it's fully testable. It takes your location, the live buses, and the chosen option, and says which step you're on:
   - **Walk to the stop:** "Your bus is 4 min away."
   - **Wait:** "Bus 2146 arrives in 2 min." If that bus leaves without you, it switches to the next bus on the same route.
   - **Ride:** it counts you as aboard once you're within about 40 m of that bus for two updates in a row. "4 stops left."
   - **Get off next:** set when the bus passes the stop before yours. "Get off at the next stop: 6 MetroTech." This is the buzz moment.
   - **Walk to the destination**, then **Arrived** within about 50 m of the destination. The trip ends after 2 hours no matter what.
   Tests replay scripted locations through each step, plus a missed bus and a bus that vanishes from the feed.
3. Trip screen: a **Go** button on the chosen shuttle option. While a trip runs, the panel shows the current step in large text with an **End trip** button, and the map follows you. Home shows a "Trip in progress" row to get back to it.
4. Analytics: `trip_started` and `trip_ended` (arrived or ended early). No places or coordinates, same as every other event.

## Part 2b: Pocket mode (one PR; Sonnet)
1. **Background tracking during a trip only.** This uses `CLBackgroundActivitySession` and the "location" background mode. The permission stays "While Using"; iOS shows a blue location pill while a trip runs. Nothing is tracked once the trip ends.
2. **Lock screen card (Live Activity).** This needs a new widget extension target in `project.yml`. The card shows the route badge, the bus number, the current step ("4 stops left", "Get off next stop: 6 MetroTech"), and the arrival time. In the Dynamic Island, the compact view shows the route letter and minutes, and the expanded view shows the card.
3. **The buzz.** When the step becomes "get off next," the card updates with an alert, which lights the screen with a sound and vibration. A regular notification is the backup for anyone who has Live Activities turned off. iOS asks for notification permission the first time you tap Go.
4. **Privacy page and App Review.** The privacy page says location is used in the background only during a trip you started, and is never sent anywhere. The review notes explain the same.

## What could break or cost
- Background location and Live Activities are the two things Apple's reviewers look at closely. The app needs a clear reason, and "you tapped Go" is one. The TestFlight build with this needs to go through beta review again.
- The new extension gets its own bundle ID (`com.schwaigs.bussin.LiveActivity`). Automatic signing should register it. If it doesn't, Chris adds it at developer.apple.com the same way as before. No cost.
- Battery: GPS stays on only during a trip.
- The "you're aboard" guess can be wrong if you stand next to the bus without getting on. The step only advances to "ride" after the bus has moved off with you near it.

## How it gets checked
- Unit tests for the slicing, `busId`, and every `TripSession` step.
- Simulator: `xcrun simctl location` can replay a walk-then-ride route, and the lock screen card shows in the simulator too.
- Chris rides a real shuttle with Go on.
