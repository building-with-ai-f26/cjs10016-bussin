# Bussin logo exploration

Work in progress on the Bussin logo and app icon. Each file is a standalone page you can open in a browser. It shows the wordmark, the app icon at iOS sizes, and how the icon looks in light, dark and tinted modes.

| File | What's in it | Outcome |
| --- | --- | --- |
| [round-1-flat-icons.html](round-1-flat-icons.html) | Three flat icons: a route-shaped "b", a bus in a map pin, a bus with a live signal | Rejected. Too generic. |
| [round-2-five-directions.html](round-2-five-directions.html) | Five different styles: bus mascot, countdown ring, winding-road S, Manhattan grid, transit pass | Rejected. Still didn't feel like New York. |
| [round-3-nyc-inspired.html](round-3-nyc-inspired.html) | Nine lettering ideas based on NYC references: subway mosaics, station signs, street signs, the old fare card, the station entrance lamp, subway seats, the rooftop hotel sign, the bus LED display, and letters packed into a bus shape | Shortlisted #1, #2, #5 and #8 |
| [round-4-shortlist.html](round-4-shortlist.html) | The shortlist, refined | Main logo not yet chosen |

## Where things stand

- **In use for now:** the Station sign icon is the app icon as of Nov 12, 2026. `tools/make-app-icon.swift` draws it. This may change.
- **Still in the running for the main logo:** Mosaic, Station sign, and Bus display.
- **Station lamp:** dropped as the main logo. Its icon will be an optional retro app icon people can pick in Settings (it's in the PRD's Future Features).
- **Open question:** which of the three becomes the main logo. One option on the table is pairing them: the Bus display "B" as the app icon and the Station sign as the wordmark.

## Notes

- These designs borrow the *look* of NYC signage. They don't copy MTA, MetroCard or hotel artwork, and the final logo should stay far enough from those to not look official.
- Some of the lettering uses system fonts (Helvetica Neue) and renders best on a Mac or iPhone. The final files will turn the text into outlines.
- The final app icon will be rebuilt in Apple's Icon Composer as layers so iOS can apply its glass effect.
