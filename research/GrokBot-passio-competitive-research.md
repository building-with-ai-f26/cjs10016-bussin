# PassioGo and Passio Technologies: Competitive Research

**Research date:** November 10, 2026 (America/New_York)

Two reports in one file: (1) public sentiment and complaints about the PassioGo rider app, and (2) Passio Technologies as a company plus the competitor landscape. Quotes, attributions, dates, figures, and source URLs are preserved from the underlying research. Nothing here was invented; uncertainty caveats are kept in place.

## Executive summary

- Passio Technologies is a hardware-plus-software CAD/AVL vendor, not a rider-app-only company. It has been owned since 2020 by Transit Technologies, a PE roll-up recapped by PSG (2019 and January 2025). The firm still claims “over 250 clients,” a figure that also appears in a ~2020 anniversary post and may be stale. Passio GO is the rider front end of a broader stack (MDT/VLU hardware, dispatch, APC, AVA, access control, and paratransit via ParaPlan/TripMaster).
- Headline app-store ratings look decent — Apple App Store 4.6 out of 5 with “11K Ratings,” Google Play 4.1 with about 1.66K–1.68K reviews, both read on November 10, 2026 — but written reviews and campus discourse skew much more negative. A University of Chicago survey (June 25, 2025) found about half of respondents “somewhat or very dissatisfied with the app.”
- The dominant rider complaints are inaccurate or jumping ETAs, ghost/frozen/missing buses, a confusing or dated UI and weak trip planning, crashes and agency kick-outs, wrong or stale stop data, and a broken in-app feedback form. Ads and battery drain were not noticeable themes. r/UIUC and r/uofm had no meaningful Passio discussion.
- Public pricing signals: a 2022 Canby quote listed Passio GO recurring at $699 per vehicle per year before discount (plus hardware/install); a Daily Targum article, indexed but returning 403 when fetched, stated Rutgers’ Transdev–Passio contract was $10,000 per month through July 2026; USF’s 2022 deal had capital costs of over $350,000 and annual operating costs of over $31,000.
- In 2024–2026 Passio still won some RFPs (NC State left TransLoc for Passio GO in August 2024) but lost Harvard to Citymapper (Via) on July 1, 2026 and Harrisonburg/JMU to Avail’s myStop. The University of Alabama and Baltimore’s Charm City Circulator moved tracking to TripShot — a Transit Technologies sister brand since March 2024, so those moves are intra-parent from a corporate view.
- Competitors span hardware CAD/AVL (TransLoc/Modaxo, ETA Transit, Peak Transit, Avail, GMV Syncromatics), software rider front ends (Transit app, Citymapper), and adjacent on-demand or scheduling tools (Via, Spare, RideCo, Optibus). Student-built apps at Rutgers and NYU already try to beat Passio’s UX on the same official feed.
- Switching costs — proprietary onboard hardware and contracts often held by shuttle operators such as Transdev or LAZ — are Passio’s moat. The clearest opening for a new entrant is a trusted rider app (accurate ETAs, no ghost buses, stop-first UX) on standards-based or hardware-optional AVL and a stable GTFS-RT/public API, sold to the university rather than only bundled with the bus contractor.

---

## 1. Public sentiment and complaints about PassioGo

Sources covered: Apple App Store and Google Play listings (fetched November 10, 2026), campus and city subreddit threads, X posts (full-archive search via X tools), campus newspapers, an official UChicago survey, and a Cambridge City Council policy order. I did not find meaningful Passio discussion on r/UIUC or r/uofm — those campuses do not appear to use the app. Ads and battery-drain complaints were not a noticeable theme in the sources reviewed. Organic X volume is low compared with Reddit and app-store reviews.

### 1.1 Overall sentiment and app-store ratings

Ratings below were read on the official store pages on November 10, 2026:

- **Apple App Store:** 4.6 out of 5, “11K Ratings.” [Passio GO on the App Store](https://apps.apple.com/us/app/passio-go/id1203861956)
- **Google Play:** the header showed “4.1 star” and “1.68K reviews”; the ratings section on the same page showed “4.1” and “1.66K reviews.” A more precise count was not available. [Passio GO! on Google Play](https://play.google.com/store/apps/details?hl=en&id=com.passio3.go)

Headline stars look decent, especially on iOS. Written reviews actually opened skewed much more negative (lots of 1–2 star writeups about ETAs, ghosts, UI, and crashes). Some reviewers allege rating inflation (“bot reviews,” “paying for fake reviews”); that was not independently verified.

Campus evidence is clearly worse than the star average. UChicago’s June 25, 2025 transportation survey said “about half of respondents” were “somewhat or very dissatisfied with the app.” [Safety and Transportation – Summer Update, University of Chicago](https://csl.uchicago.edu/news/article/safety-and-transportation-summer-update/)

### 1.2 Main pain-point themes (ranked by how often they showed up)

#### 1) Inaccurate, jumping, or stalled ETAs — dominant

This is the complaint that shows up everywhere: App Store and Play written reviews, campus papers, Reddit, and X. Riders describe “1 minute away” that never arrives, ETAs that jump to 30–45 minutes, or the app tracking the following bus.

> “The bus frequently just won’t show up when it says 1-minutes away.”

— spromine, App Store, Oct 1 (year not shown on the review card). [App Store reviews](https://apps.apple.com/us/app/passio-go/id1203861956?platform=iphone&see-all=reviews)

> “I’ve been late to class several times because I check on the app and the bus is late or delayed or it says it’s coming, but it’s actually out of service.”

— Emma A. Lucas ’27, [The Harvard Crimson, March 5, 2025](https://www.thecrimson.com/article/2025/3/5/alternatives-passio-go/)

> “PassioGo is the worst bus app ever! Is my bus coming in 13 minutes or 2 dammit”

— @Nia_piaa1, X, November 26, 2019, 6:02 PM ET. [Post](https://x.com/Nia_piaa1/status/1199463568996995072)

#### 2) Ghost/phantom buses, frozen or missing GPS, buses in the wrong place — very common

Tied closely to ETAs. Buses vanish, freeze then jump, appear when none exist, fail to appear when a bus is literally passing, or show up in impossible places.

> “The worst part of Passio GO! is the PHANTOM BUSES. It shows buses that are scheduled to arrive, but they never do.”

— u/FicentPick, [r/uchicago, August 21, 2026](https://www.reddit.com/r/uchicago/comments/1vu1iht/the_university_of_chicagos_shuttle_buses_are/)

> “Occasionally, buses on my PassioGo map show up in the lake. LoL”

— u/Haunting_Dust_4026, [same thread](https://www.reddit.com/r/uchicago/comments/1vu1iht/the_university_of_chicagos_shuttle_buses_are/)

> “Used to work, but now constantly says service has not started while I am staring at a bus in service drive past me.”

— Lauren Tucker, Google Play, July 15, 2026. [Google Play listing](https://play.google.com/store/apps/details?hl=en&id=com.passio3.go)

Official operators also admit tracking gaps: WRTD posted that a Blue Line bus was running “but the bus is not currently tracking in PassioGO” (September 11, 2026, 8:14 PM ET). [WRTD post](https://x.com/wrtdct/status/2098565756766290350)

#### 3) Confusing, dated UI and weak trip planning — very common

Riders say the core job — “when is the next bus at my stop, and how do I get from A to B?” — is hard. Recurring specifics: the user’s location dot sits on top of the stop so taps open the wrong thing; route filters don’t stick; only the next bus is shown, not later ones; depart/arrive-by time pickers are broken; no obvious schedule tab.

> “It refuses to give an accurate eta on busses, it is wildly confusing to use, half of the time the stops just don’t appear on the map, and the UI is good awful.”

— u/Buffsub48wrchamp, [r/KSU, January 7, 2025](https://www.reddit.com/r/KSU/comments/1hw281e/passio_go/)

> “The UI fucking SUCKS. It feels like it’s stuck in 2016… the notification for a bus about to arrive is unreliable and it used to log me out randomly.”

— u/imhysterical, [r/KSU, April 29, 2025](https://www.reddit.com/r/KSU/comments/1ka14a8/passio_go_is_the_worst/)

> “it took me about 20 minutes of trial and error to figure out how to navigate from one stop to another with a single transfer”

— jgraha45, App Store, October 30, 2025. [App Store listing](https://apps.apple.com/us/app/passio-go/id1203861956)

#### 4) Crashes, connection errors, and getting kicked out of an agency — common

Crashes on open, “no connection” on working Wi-Fi, having to re-enter agency/route, and (at SCAD) being locked out of the school’s agency.

> “Every time that I try to open the app, the first time, it always crashes.”

— Maxwell W. Zen ’26, [The Harvard Crimson, April 1, 2026](https://www.thecrimson.com/article/2026/4/1/harvard-passio-go-extension/)

> “I cannot count how many times this awful app has just totally kicked me and my friends out of the ‘agency’… and refuses to let us get back in.”

— Sukihs (SCAD student), App Store, April 27, 2025. [App Store listing](https://apps.apple.com/us/app/passio-go/id1203861956)

> “the Passio GO! app loves to crash on me. Kinda hard to track the shuttles when the app decides never to work...”

— @jrmillan17, X, August 31, 2023, 1:02 PM ET. [Post](https://x.com/jrmillan17/status/1697293792368365789)

#### 5) Wrong or stale stop, route, and schedule data — common, especially at cutovers

Stop pins don’t match where drivers stop; inbound/outbound stops are merged; printed/website schedules disagree with the app; routes show streets the bus does not use.

University of Rochester’s *Campus Times* (February 4, 2024) documented wrong route geometry, a stop placed in a parking lot, and inbound/outbound stops shown as one pin. Transportation staff told students to use the printed website schedule instead. [Passio Go! shuttle-tracker launches with big bug problems](https://www.campustimes.org/2024/02/05/passio-go-shuttle-tracker-launches-with-big-bug-problems/)

> “the app shows bus stops that do not match the locations bus drivers identify as the actual stops.”

— Jsonn33, App Store, June 10 (year not shown on the card). [App Store reviews](https://apps.apple.com/us/app/passio-go/id1203861956?platform=iphone&see-all=reviews)

At RIT, a student wrote that Passio and the official website “would say two completely different things” and advised “Don’t use passio go, stick to the schedule on the RIT website.” — u/WarSmith66, [r/rit, September 26, 2024](https://www.reddit.com/r/rit/comments/1fnxokh/why_is_passio_go_so_fucked/)

#### 6) Broken in-app feedback — recurring in written reviews

The feedback keyboard covers the send button, or the form simply doesn’t submit. This showed up repeatedly in 2025–2026 iOS reviews.

> “Any time you click the feedback button, there’s no way to get rid of the text box so you can send your bug report.”

— kayliiiiiii boi, App Store, December 2, 2025. [App Store reviews](https://apps.apple.com/us/app/passio-go/id1203861956?platform=iphone&see-all=reviews)

Harrisonburg later cited faster vendor feedback as one reason it replaced PassioGO! with myStop. [New bus app ‘myStop’ replaces ‘PassioGO!’ citywide, The Breeze](https://www.breezejmu.org/news/new-bus-app-mystop-replaces-passiogo-citywide/article_3fccc5d3-97f8-4ce5-a0fb-2686bb439f4a.html)

#### 7) Unreliable arrival alerts; service marked “not running” when it is — moderately common

Alarms miss; weekend/evening routes show as inactive; CityLink in Lewiston, Maine and RIT weekend service were called out this way.

> “It kept saying that it wasn’t running, but when I checked with the bus driver, she Said all lines were running.”

— Catmominme, App Store, January 10 (year not shown; Citylink, Lewiston, Maine). [App Store reviews](https://apps.apple.com/us/app/passio-go/id1203861956?platform=iphone&see-all=reviews)

#### 8) Accessibility — less frequent in volume, but severe where it appears

Passio has shipped many VoiceOver fixes (versions 5.5 through 6.1.2 on the App Store version history), which itself signals a real problem. A blind reviewer said they could not select a route or hear pickup/drop-off times with a screen reader and did not recommend the app. That review was read on a third-party App Store aggregator (appsupports.co), not re-confirmed on Apple’s live page: [Passio GO Negative Reviews](https://appsupports.co/1203861956/passio-go/negative-reviews) (reviewer “Blind madness,” listed on version 6.0.0).

#### 9) Multi-agency / coverage friction — occasional

Users report losing a second agency, search not finding a school, or an outage in Passio taking down every campus app that depends on its API (explicitly noted at Rutgers).

> “Quite literally the glitchiest app ever. Oftentimes, it will not display the buses while the other apps manage to… If a full outage happens, it knocks out all the other bus apps.”

— [r/rutgers app comparison, about September 2025](https://www.reddit.com/r/rutgers/comments/1n6990w/which_rutgers_bus_app_is_best_for_you_pros_cons/)

#### X coverage note

Organic rider posts exist but are sparse and low-engagement compared with Reddit and app-store reviews. Many X hits are agency promotions. The useful X signal is official “tracker down / bus not tracking” alerts, plus short student vents such as “passio go will have you late af to class” ([@prxncessbran](https://x.com/prxncessbran/status/1235348377765916679), March 4, 2020, 6:36 PM ET) and a Kent State rider saying the switch to Passio Go was “miserable and half the tracking doesn’t work” ([@queeratkent](https://x.com/queeratkent/status/1826998050625097904), August 23, 2024, 11:00 AM ET). There is no @passiogo account.

### 1.3 What people like

When the live map is actually updating, people like seeing the bus icon and using the app as a route/stop map. A few call it “better than nothing,” or useful if they ignore ETAs and watch the map ([r/uchicago](https://www.reddit.com/r/uchicago/comments/1vu1iht/the_university_of_chicagos_shuttle_buses_are/)). Positive notes also include: no account required; a web/desktop tracker; Apple/Google base maps (called out as better than TransLoc’s map in a 2023 r/rutgers post); favorites and an arrival alarm when they work; and occasional “it’s reliable” comments (a Harvard Medical School student in the [April 1, 2026 Crimson piece](https://www.thecrimson.com/article/2026/4/1/harvard-passio-go-extension/)). A University of Rochester transportation intern said Passio did not require location services and offered more customization than TransLoc, even while calling the UI worse. [Campus Times, February 4, 2024](https://www.campustimes.org/2024/02/05/passio-go-shuttle-tracker-launches-with-big-bug-problems/)

Additional campus-paper color (mixed, not only negative):

- At CSULB, some unreliability was blamed on drivers turning tracking off; a staffer said shuttles do not have specific arrival times, which students often misunderstand. [The Beach’s Passio GO shuttle app creates student uncertainty, Long Beach Current, January 23, 2024](https://lbcurrent.com/news/2024/01/23/the-beachs-passio-go-shuttle-app-creates-student-uncertainty/)
- At Chapman, Biola Fatusin said she found the app useful once she discovered ETAs, but also that it was “confusing to learn since a tutorial is not provided,” and that the app said a shuttle “was coming at a certain time, but it didn’t… It was actually far, far away.” Another student deleted the app and used a printed RA schedule instead. The Panther article is dated Oct 20 (year not shown on the fetched page; the byline identifies the author as 2023-24 editor-in-chief). [Chapman community describes complications with shuttle service](https://www.thepanthernewspaper.org/news/c084r98ejhefu8chawvuzd4uj7935m)
- The University of Alabama’s *Crimson White* (February 24, 2020) said times were inaccurate by 5–10 minutes, out-of-service buses kept showing as active, and routes sometimes failed to appear on the map, while still praising the concept and some map/stop tools. [The PassioGo App Needs to Go](https://thecrimsonwhite.com/62748/opinion/the-passiogo-app-needs-to-go/)

### 1.4 Business and vendor notes from rider and campus coverage

Who buys it: universities and smaller transit agencies, often via the shuttle contractor, not a student download choice. Documented or clearly implied users include Harvard (until July 1, 2026), UChicago, Rutgers, Georgia Tech, NCSU, KSU, RIT, University of Rochester, University of Alabama (until August 2026), CSULB, Chapman, SCAD, NYU, JMU/Harrisonburg (until August 2026), Baltimore Charm City Circulator (until mid-2026), UConn/WRTD, Bayway, St. Louis Airport parking shuttles, and Cambridge’s EZ Ride. At CSULB the app came bundled with the LAZ Parking shuttle contract. [Long Beach Current](https://lbcurrent.com/news/2024/01/23/the-beachs-passio-go-shuttle-app-creates-student-uncertainty/) At Rochester, staff said they switched because TransLoc’s price jumped and the old app was no longer supported; Transdev migrated UR and RIT together. [Campus Times](https://www.campustimes.org/2024/02/05/passio-go-shuttle-tracker-launches-with-big-bug-problems/)

Hardware lock-in: Passio uses onboard equipment. Harvard’s student government was told a replacement required physical hardware changes that could only happen over the summer. [The Harvard Crimson, April 1, 2026](https://www.thecrimson.com/article/2026/4/1/harvard-passio-go-extension/) Harrisonburg said Passio GPS units were pulled from buses when it moved to myStop. [The Breeze](https://www.breezejmu.org/news/new-bus-app-mystop-replaces-passiogo-citywide/article_3fccc5d3-97f8-4ce5-a0fb-2686bb439f4a.html)

Competitors people actually name in this complaint corpus: TransLoc (the most common comparison, often “why did we leave?”); the Transit app; Google Maps; Citymapper (Harvard’s 2026 replacement after interviewing “more than 20 vendors”); TripShot (Alabama and Baltimore Circulator, 2026); myStop/Avail (Harrisonburg/JMU, 2026). Student-built alternatives already exist on Passio’s data, notably Rutgers’ RUBus and XRadar and NYU’s NYUBus. No meaningful DoubleMap or RideSystems mentions were found in these complaint sources.

Civic pressure: Cambridge City Council unanimously adopted Policy Order 2025-20 on March 3, 2025, asking the city manager to press EZ Ride and Passio to fix tracking deficiencies. [POR 2025-20, The Cambridge Record](https://cambridgerecord.org/items/por-2025-20.html)

Company (from the Play listing): Passio Technologies Inc / Transit Fixed / On-Demand, LLC, Sandy Springs, GA; support@passiotech.com.

Harvard context that also belongs here: students called the app “unreliable” and “never really accurate”; Alan Huang ’27 said it “feels like someone threw it together in two minutes and called it a day.” The university later extended the contract month-to-month, scrapped an HUA-backed student-app competition over maintenance and onboard hardware, then replaced Passio GO with Citymapper on July 1, 2026. [March 5, 2025](https://www.thecrimson.com/article/2025/3/5/alternatives-passio-go/), [April 1, 2026](https://www.thecrimson.com/article/2026/4/1/harvard-passio-go-extension/), [July 12, 2026](https://www.thecrimson.com/article/2026/7/12/harvard-citymapper-shuttle-tracking-app/)

### 1.5 Opportunities for a competitor (derived from the complaints)

- Make ETAs trustworthy, and be honest when they’re not: show live vs. scheduled, stale/frozen GPS, and “bus not reporting” instead of a fake 1-minute arrival or a phantom trip.
- Stop-first UX: tap a stop (even if the user is standing on it) and see every upcoming bus, not just the next one; don’t let the location dot steal the tap.
- Real A-to-B trip planning (transfers, working depart/arrive-by, later buses), which is what Citymapper was praised for after Harvard switched.
- Reliable, opt-in arrival alarms that actually fire.
- Don’t lock campuses into proprietary hardware if you can use standard AVL / GTFS-Realtime — lock-in is a sales moat for Passio and a reason replacements slip to summer.
- A stable public API so student apps don’t die in an official outage — and so you can beat Passio on prediction quality using the same feed, which Rutgers students already claim to do.
- A feedback form that submits, and an onboarding tutorial (Chapman students said they discovered ETAs “by accident”).
- Accessibility as a launch requirement, not a multi-year patch list.
- Win on rider experience, not just a cheaper bundle for the bus contractor. Several schools left TransLoc for Passio on cost, then faced years of student backlash; some (Harvard, Alabama, Baltimore, Harrisonburg) later left Passio too.

---

## 2. Passio Technologies as a company

### 2.1 What it sells

A modular hardware-plus-software stack for university, municipal, corporate, healthcare, aviation, residential, and hospitality fleets — not a rider-app-only company. Official product set on [passiotech.com](https://passiotech.com/) and [leads.passiotech.com](https://leads.passiotech.com/):

- **Passio GO:** rider app / public screens for live location, ETAs, alerts (and Request & GO, an in-app ride/stop request).
- **Passio Navigator** and **Passio OpsView:** CAD/AVL, dispatch, live map, alerts (speeding, off-route, idle), analytics/“report cards.”
- **On-vehicle hardware:** Passio MDT (rugged Android driver tablet) and VLU (vehicle logic unit), GPS/cellular, J1708/1939, CAN, GPIO, etc. [CAD/AVL page](https://passiotech.com/cadavl/)
- APC, AVA (automated voice announcements), onboard LED signs, optional Wi-Fi, Passio Vision cameras (via Vestige).
- **Passio Gateway:** tap/swipe/scan boarding access and demographic reporting (described as student/employee ID, not a full fare-collection suite of its own).
- **BusBuzz:** rider feedback by text/mobile web.
- **Paratransit / NEMT / on-demand:** Passio acquired ParaPlan in 2019; on-demand and small-scale fixed route are also offered with sister company CTS Software’s TripMaster. [About Us](https://passiotech.com/about-us/)

The about page still says “transit and parking solutions,” but a current, standalone parking product page was not found. “Contact Tracing” is still listed; that language looks leftover from 2020.

### 2.2 Business model and pricing signals

SaaS/subscription plus hardware, installation, and optional modules. New customers in a 2022 quote were asked for a 50% deposit on one-time costs. “Standard term is 36 months for optimal pricing,” with a 60-month lock-in option; shorter terms “are subject to higher recurring fees.” Source: City of Canby Ordinance 1581 and attached Passio quote #979 (July 5, 2022), [ordinance PDF](https://www.canbyoregon.gov/sites/default/files/fileattachments/ordinance/26297/ord_1581.pdf)

Verified public prices (not a rate card for every deal):

- **Canby Area Transit, 16 vehicles, fixed-route Passio GO + AVA (2022).** List-ish unit prices in the quote: GO recurring $699/vehicle/year; AVA recurring $468/vehicle/year; VLU $422; MDT $846; system setup $2,354.10; installation $1,130/vehicle. After discounts, the ordinance authorized $69,290 startup and $12,928/year for five years for Passio, plus $28,940 startup and $10,380/year for TripMaster dial-a-ride. Same PDF.
- **Rutgers (August 2023 Daily Targum):** the tracking contract is “between Transdev and Passio Technologies” at “$10,000 per month through July 2026,” “the same as under the TransLoc contract,” paid from student term bills. The article could not be re-fetched (403); this is from the search index of [U. unveils new bus tracking app for campus fleet](https://dailytargum.com/article/2023/08/u-unveils-new-bus-tracking-app-for-campus-fleet).
- **USF Bull Runner (August 30, 2022):** replaced Syncromatics; five-year deal with three optional extension years; “capital costs of over $350,000 and annual operating costs worth over $31,000,” funded by the student transportation fee. [The Oracle](https://www.usforacle.com/2022/08/30/new-bull-runner-tracking-system-to-provide-more-accurate-travel-times/)
- **The Woodlands Township trolley RFQ C-2024-0615 (November 21, 2024 price analysis):** Passio four-year total $80,956 (Year 1 $45,766, then $11,730/year); Peak Transit $58,460. Optional Wi-Fi $6,270 vs $3,720; optional “new AVL of new trolley vehicles” $17,370 vs $14,550. Staff recommended Passio as best value despite a 38% higher price. The memo still says “Contract Award: Future update,” so the award was not confirmed as closed. [Price analysis PDF](https://public.destinyhosted.com/woodldocs/2024/BODREG/20241204_4004/6262_Attachment_A-Independent_Cost_Estimate_and_Price_Analysis.pdf)

### 2.3 Customer base and size

Passio’s current about page still claims “over 250 clients.” The same figure appears in its “10 Years of Passio!” post, which discusses 2020 brand guidelines, virtual tradeshows, and COVID contact tracing, so the number may be stale. An independently audited count, or a split of campuses vs. cities, was not found. [About Us](https://passiotech.com/about-us/) and [10 Years of Passio!](https://passiotech.com/blog/10-years-of-passio/)

Documented buyers include universities (Rutgers, USF, NCSU, and others from the sentiment review), small municipal systems (Canby), and FTA-grantee trolley service (The Woodlands bid). UNC Charlotte’s transit-operator RFP said the Passio relationship is “with the current transit operator and not with the University,” and that keeping Passio GO is “preferred” but not required. [UNC Charlotte RFP addendum](https://evp.nc.gov/_entity/annotation/2ea4fa06-bc0d-f111-8407-001dd80bcb64/api)

### 2.4 HQ, founding, and leadership

Official office: 6100 Lake Forrest Drive, Suite 410, Atlanta, GA 30328; 678.825.3456; info@passiotech.com. [About Us](https://passiotech.com/about-us/)

The Google Play listing listed a nearby Sandy Springs address (6000 Lake Forrest Dr Ste 455) for Transit Fixed / On-Demand, LLC — a different or older legal-entity address, not used here in place of the official website.

Founded in 2010 (co-founders R. Scott Reiser and Mitch Skyer; the 10-year post and Skyer’s public bio are consistent with that). The current about page lists Scott Reiser as “CEO, CTO, & Co-Founder.” Skyer is described there historically as co-founder; a current Passio title for him was not found on the company site.

### 2.5 Ownership and funding

Passio is not a standalone VC story anymore. It was acquired in 2020 by Transit Technologies, a PE roll-up launched in 2019 by Greater Sum Ventures with a June 2019 recapitalization by PSG, and a further PSG recap in January 2025. [GSV case study](https://greatersumventures.com/case-studies/moving-communities-forward-through-technology)

Passio’s about page itself says it “works with a number of Transit Technologies companies,” including FASTER, Vestige, MJM Innovations, CTS/TripMaster, Ecolane, and ArgoTrak.

Transit Technologies acquired TripShot on March 4, 2024 (then “over 3,000 clients”). [Acquisition announcement](https://www.transit-technologies.com/blog/transit-technologies-announces-strategic-acquisition-to-enhance-mobility-solutions)

An August 18, 2026 Transit Technologies release says the parent “powers more than 4,000 clients worldwide,” has “delivered more than 54 million rides,” and is wrapping Ecolane, TripShot, TripMaster, Vestige, Passio, ByteCurve, busHive, and FASTER under an AI suite called TransitTechOS, with a “Connected Campus” and “Connected Agency” split. GSV’s writeup uses different scale claims (“more than 100 million rides annually,” “more than $6.8 billion in transit assets”); those figures are not reconciled here. [PR Newswire, August 18, 2026](https://www.prnewswire.com/news-releases/transit-technologies-introduces-transittechos-the-only-ai-first-transit-operating-suite-built-on-the-industrys-deepest-operational-experience-302853360.html)

Cooperative purchasing: Transit Technologies (including Passio, TripShot, TripMaster, Ecolane, FASTER, Vestige, MJM, Bytecurve) holds 791Coop contract 791202505001, awarded July 29, 2025. [791Coop vendor page](https://www.791coop.org/vendordetails.html?cnt=791202505001&vtn=23748)

### 2.6 Employee count

Only first-party signal: the ~2020 anniversary post said the team had grown “from 5 employees to over twenty.” Third-party scrapes (for example, LinkedIn “28”) are unverified and are not treated as fact.

### 2.7 Recent wins and losses, 2024–2026

**Wins / stay:**

- NCSU left TransLoc for Passio GO in August 2024 after an RFP. Transit manager Connor Jones cited TransLoc’s Ford then Modaxo ownership changes, “about 16 months” without a dedicated rep, better push alerts, full-day schedules, Google Maps integration, and “really granular data.” Students already complained about ETA accuracy and overlapping routes. [NC State changes bus tracking apps, Technician, August 26, 2024](https://technicianonline.com/76862/news/nc-state-changes-bus-tracking-apps/)
- The Woodlands recommended Passio over cheaper Peak Transit in November 2024 (award not confirmed in the memo above).
- Rutgers’ Transdev–Passio deal was slated through July 2026 (Targum, as above, with the 403 caveat).

**Losses** (from this company review and the sentiment review; all documented):

- Harvard replaced Passio GO with Citymapper on July 1, 2026 after a year-long review and “more than 20 vendors.” Official apps page: [Harvard Transportation, Download Apps](https://transportation.harvard.edu/download-apps) and [The Harvard Crimson, July 12, 2026](https://www.thecrimson.com/article/2026/7/12/harvard-citymapper-shuttle-tracking-app/)
- University of Alabama and Baltimore’s Charm City Circulator moved rider tracking to TripShot in 2026. Important caveat: TripShot has been a Transit Technologies sister brand since March 2024, so those “Passio to TripShot” moves are intra-parent from a corporate view.
- Harrisonburg / JMU replaced PassioGO! with Avail’s myStop in summer 2026; the city said Passio “was certainly getting the job done” but wanted a better vendor relationship and faster feedback. Passio GPS units were pulled from buses. [The Breeze](https://www.breezejmu.org/news/new-bus-app-mystop-replaces-passiogo-citywide/article_3fccc5d3-97f8-4ce5-a0fb-2686bb439f4a.html)

---

## 3. Competitor profiles

### TransLoc (Modaxo; not currently Ford or Via)

Fixed-route CAD/AVL, on-demand/microtransit, rider/driver apps, GTFS tools. Targets agencies, universities, airports, healthcare, corporate/hospitality. Durham, N.C.; founded 2004. Ford owned it; Modaxo bought it from Ford on March 1, 2022, and said that while in Ford’s portfolio it supported “more than 1,500 transport providers” and “more than 600 million rides” a year (that figure is as of 2022, not updated here). [Modaxo Welcomes TransLoc](https://modaxo.com/insights-into-transportation-technology/modaxo-welcomes-transloc/) and [TransLoc, Our Company](https://transloc.com/our-company/)

Hardware + software historically; current site emphasizes SaaS and GTFS. Momentum mixed: many campuses left after the Ford/Modaxo period (NCSU, GoRaleigh per the Technician; Rochester/RIT and others in the sentiment review cited cost and end-of-support). At NCSU, staff still said TransLoc was “awesome at wayfinding,” while students later missed its cleaner map. A current public price list was not found.

### Via, and Citymapper (owned by Via since March 2023)

Via: on-demand / microtransit software and operated services for cities, agencies, and campuses. Harvard Evening Van has used Via tech since a 2018 license deal. [Via announcement, August 20, 2018](https://ridewithvia.com/news/via-to-provide-its-technology-and-support-services-for-harvard-universitys-evening-van-service)

Citymapper joined Via in 2023; consumer apps continue, and journey-planning/APIs feed “Citymapper for Cities” (co-branded MaaS app, disruption alerts, planning insights). [Citymapper joins Via](https://citymapper.com/news/2582/citymapper-joins-via) and [Citymapper for Cities by Via](https://ridewithvia.com/solutions/citymapper)

Harvard now tells riders to use Citymapper for Harvard Shuttles, Evening Van, MBTA, BlueBikes, and M2; the same official page still tells M2 riders to download TransLoc. [Download Apps](https://transportation.harvard.edu/download-apps) Rider reviews of Citymapper after the switch were mixed (better trip planning and accuracy, busier UI). Software-front-end model; Harvard’s earlier coverage said Passio’s onboard hardware was a switching-cost issue, but a public Citymapper hardware SKU was not seen.

### TripShot (Transit Technologies since March 4, 2024)

Cloud campus/corporate mobility: fixed route, on-demand, parking, micromobility, trip planning, capacity, “True-Time® Arrivals,” GTFS/GTFS-RT “from Day 1,” APC/AVA/badge integrations, WCAG 2.1 AA / VPATs, SSO, ISO 27001. Positions hard at universities. [TripShot universities](https://tripshot.com/universities)

Founded 2008 (Silicon Valley; Fortune 500 commuter fleets). Recent campus/city wins include Alabama Crimson Ride and Baltimore Circulator (2026), plus Troy University coverage. Same PE parent as Passio. No public list prices found.

### Avail / myStop

CAD/AVL + myStop rider app, aimed at mid-size agencies (and campuses that share a city system, e.g., HDPT/JMU). Hardware + software. Harrisonburg said myStop is “very similar” to Passio but promised faster feedback and a better vendor relationship; Avail customized the app and replaced Passio’s onboard GPS. Employee-ownership and a current customer count were not independently verified. No public unit pricing found. [JMU / The Breeze article](https://www.breezejmu.org/news/new-bus-app-mystop-replaces-passiogo-citywide/article_3fccc5d3-97f8-4ce5-a0fb-2686bb439f4a.html)

### RideSystems and DoubleMap

Merged in 2019 into Journey Holding; Ford bought Journey Holding in 2019 and planned TransLoc integration. [PR Newswire merger](https://www.prnewswire.com/news-releases/ride-systems-llc-and-doublemap-inc-merge-to-form-journey-holding-corp-300778280.html) and [TechCrunch, July 30, 2019](https://techcrunch.com/2019/07/30/ford-acquires-software-company-journey-holding/)

After that, the brands are hard to treat as independent. At the University of South Alabama, the DoubleMap JagTran tracker “stopped working” in spring 2023 after prior outages and was replaced by ETA Spot in early 2024; the student paper also said Auburn and others affected by DoubleMap’s loss went to ETA. [Jag Media, February 17, 2024](https://jagmedia.org/2024/02/17/students-relieved-as-new-jagtran-tracker-app-is-unveiled/)

A currently independent RideSystems or DoubleMap commercial site was not confirmed.

### Syncromatics / GMV

GMV completed its Syncromatics takeover in 2018. CAD/AVL and real-time passenger info. USF left Syncromatics for Passio in 2022 after “consistent inaccuracy” ([The Oracle](https://www.usforacle.com/2022/08/30/new-bull-runner-tracking-system-to-provide-more-accurate-travel-times/)). Still a mid/large-agency ITS vendor; less visible in 2024–26 campus headlines opened for this research.

### Swiftly

Software-only transit data platform: GTFS-RT passenger info, operations, performance/ridership analytics (acquired Hopthru in 2024). “Over 190 transit agencies in 12 countries,” including “over half of the largest 25 agencies in the US by bus ridership,” per a May 29, 2025 investment announcement led by Cove Hill Partners with JMI Equity; CEO Jonathan Simkin remains. Aimed at city agencies, not campus hardware AVL. Current per-vehicle list prices were not independently re-verified (older contract quotes exist but were not re-read). [Swiftly / Cove Hill announcement](https://www.goswift.ly/blog/cove-hill-partners-investment)

### Transit app (Montreal; partners@transit.app)

Consumer trip-planning app that ingests an agency’s existing GTFS / GTFS-RT. Not a CAD/AVL vendor. Campus page (updated June 29, 2026) lists UC Berkeley, Kentucky, Maryland / UMBC, Iowa CAMBUS, and CU Boulder, plus “180+ regional transit agencies.” Offers public or community-only (geofenced/secure URL) campus routes, alerts, accessibility features, and a “Royale” premium tier with university branding. Low implementation lift if the feed already exists — a wedge against requiring students to install Passio GO. [University and College Partnerships with Transit](https://resources.transitapp.com/article/587-campus-partnerships)

Riders on several campuses in the sentiment review already preferred Transit when the feed was present.

### Spare

Demand-response / paratransit / microtransit software (not a fixed-route campus tracker). Series B of $42 million CAD, September 10, 2024, led by Inovia Capital. Named agency customers include DART, BART, AC Transit, GoDurham ACCESS, CapMetro Access; “eight of the 10 largest cities in the United States.” [Spare Series B release](https://spare.com/press-releases/spare-secures-42m-in-series-b-funding-to-accelerate-growth-in-demand-response-transit-solutions)

COAST (NH) board minutes of July 22, 2026 say Spare for demand-response/TripLink was expected to go live October 1, 2026. [Approved board minutes PDF](https://coastbus.org/sites/default/files/pdfs/Approved%20Board%20Minutes/FY26/Approved%20Board%20Minutes%20072226.pdf)

### Optibus

Cloud planning/scheduling/ops for public transit (and some large private shuttles), not a Passio-style campus rider app. Series D $100 million at a $1.3 billion valuation, May 2022. [PR Newswire](https://www.prnewswire.com/news-releases/optibus-becomes-the-first-public-transportation-unicorn-with-series-d-closing-301547388.html)

Competes more with scheduling suites than with Passio GO.

### ETA Transit

Campus- and mid-size-agency CAD/AVL with rugged VLUs (explicitly selling against “consumer-grade tablets”), SPOT rider app, infotainment. Company blog (September 25, 2025) says Indiana University (28 vehicles, 6 routes) and University of Delaware (17 vehicles, 6 routes) switched to SPOT; IU staff are quoted on prior server crashes and bad ridership data; UDEL said a liked platform was sunset after an acquisition and they were “forced” onto a worse system. That post does not name the prior vendor. [Why Universities Are Upgrading…, ETA](https://etatransit.com/resources/blog/why-agencies-are-leaving-competitors-for-etatransit/)

Independently, South Alabama’s student paper (February 17, 2024) says ETA Spot replaced a dead DoubleMap app and that ETA “boasts… over 75 transit agencies” and has been in the business since 2003 (company claim, via the paper). Students were “relieved.” [Jag Media](https://jagmedia.org/2024/02/17/students-relieved-as-new-jagtran-tracker-app-is-unveiled/)

Stony Brook also launched “ETA Spot” (separate student coverage exists). Pricing was not found.

### RideCo

On-demand / microtransit optimization software for agencies and some corporate shuttles. TechCrunch (February 17, 2022) reported a $16 million raise. Not a primary fixed-route campus AVL play. A 2024–26 primary update was not fetched.

### Peak Transit

Direct campus/small-agency CAD/AVL alternative: MDTs or existing tablets, branded rider app, APC, AVAS, digital signs, GTFS/GTFS-RT, NTD reporting. Marketed as 4-week (existing hardware) or 8-week (new hardware) installs. Undercut Passio on price at The Woodlands and still lost the staff recommendation. [Peak Transit universities](https://www.peaktransit.com/universities)

### Campus / student-built trackers (not full vendors)

Rutgers students built RUBus and XRadar on Passio’s API and, in a 2025 campus comparison, called official Passio “the glitchiest” with better location than ETAs; student apps were said to beat official wait times until a Passio outage takes them all down. [r/rutgers comparison](https://www.reddit.com/r/rutgers/comments/1n6990w/which_rutgers_bus_app_is_best_for_you_pros_cons/) NYUBus is a student-built NYU shuttle app positioned as easier than Passio GO. [r/nyu, NYUBus](https://www.reddit.com/r/nyu/comments/1w5crze/nyubus_an_easier_way_to_track_nyu_shuttles/) Harvard’s student-government plan for a student-coded replacement was scrapped over hardware/maintenance concerns. These are a product signal, not funded competitors.

---

## 4. Comparison table

| Company | Segment | Hardware | Rider-app reputation (as described, not a score) | Pricing signals | Recent momentum |
| --- | --- | --- | --- | --- | --- |
| Passio (Transit Technologies / PSG) | Campus + small/mid agencies; fixed route, some on-demand | Proprietary MDT/VLU + signs/APC/AVA | Weak among riders (ETA/ghost-bus/UI complaints); some staff like the data/alerts | Canby 2022: ~$699/vehicle/year list for GO before discount; Rutgers indexed at $10k/month; USF 2022 >$350k capital + >$31k/year | Still winning some RFPs (NCSU 2024) but lost Harvard; some accounts moved to sister brand TripShot |
| TripShot (same parent) | Campus, corporate, some city circulators | Integrations; cloud platform; GTFS-RT day one | Marketed as stronger trip planning/arrivals; limited independent rider reviews in this pass | Not public | Acquired March 2024; 2026 wins at Alabama and Baltimore Circulator |
| TransLoc (Modaxo) | Campus + agencies; fixed + microtransit | Historically bundled AVL; now SaaS/GTFS-heavy | Better wayfinding than Passio in some staff comments; many campuses soured after ownership/support issues | Not public; older campus deals exist but are stale | Sold by Ford to Modaxo (2022); notable campus/agency departures |
| Avail / myStop | Mid-size agencies (and shared campus systems) | Onboard GPS/CAD hardware | Harrisonburg called it similar to Passio, hoping for better comms | Not public | Took JMU/Harrisonburg from Passio, 2026 |
| Citymapper / Via | City MaaS + campus front-end; Via also does on-demand | Software (Harvard still had Passio hardware as a prior lock-in issue) | Harvard: better planning/accuracy, heavier UI | Not public | Via acquired Citymapper (2023); Harvard shuttle tracking, July 2026 |
| Transit app | Rider super-app / GTFS aggregator | Software-only, uses agency feed | Often preferred when the campus feed is in it | Campus partnership / Royale; no public fee | Active campus program as of June 2026; 180+ agency partners (company figure) |
| Swiftly | Large-agency RTPI, ops, analytics | Software on existing AVL/GTFS | Ops/prediction tool, not a student shuttle app | Not independently re-verified here | 190 agencies / Cove Hill + JMI, May 2025 |
| ETA Transit | Campus + mid-size CAD/AVL | Rugged VLU (sells against tablets) | USA students “relieved” vs dead DoubleMap; IU/UDEL quoted positively on vendor site | Not public | Documented campus wins 2024–25 (USA, IU, UDEL, Auburn per student paper) |
| GMV Syncromatics | Agency ITS / CAD/AVL | Hardware + software | USF left it in 2022 over inaccurate ETAs | Not public | Quiet in the campus stories opened for 2024–26 |
| Peak Transit | Campus + small fixed-route | MDT or existing tablets + signs | No rider review corpus found | Cheaper than Passio in The Woodlands 4-year bid ($58,460 vs $80,956) | In the hunt; lost at least one 2024 best-value award recommendation |
| Spare / RideCo / Optibus | Demand-response, microtransit, or scheduling — adjacent, not Passio GO clones | Mostly software | Different job (paratransit/on-demand/planning) | Spare: $42M CAD Series B (2024); RideCo: $16M (2022); Optibus: $100M Series D / $1.3B (2022) | Growing in adjacent categories |
| DoubleMap / RideSystems | Legacy campus AVL | Hardware historically | App failures/outages by 2023 at some schools | N/A | Folded into Journey Holding / Ford (2019); brand looks largely wound down |
| Student apps (RUBus, NYUBus, etc.) | Single-campus rider UX on official data | None | Often preferred UX/ETAs until the official feed dies | Free / student-built | Exist because official apps disappoint |

---

## 5. Market structure and where a new entrant could win

### How buyers procure

- Bundled with the shuttle operator (Transdev at Rutgers and, per Rochester coverage, at UR/RIT; LAZ Parking at CSULB). The university may “prefer” Passio without holding the contract (UNC Charlotte).
- Direct university or city RFP / best-value (NCSU, USF, The Woodlands, Canby via a joint Sandy RFP).
- Cooperative purchasing (791Coop contract covering the whole Transit Technologies catalog, July 2025).
- Sole-source or integrated packages when fixed route and demand-response are sold together (Passio + TripMaster at Canby; a Santa Fe listing described a TripMaster+Passio “Transit Technologies” sole-source — that packet was not re-read).

### Switching costs are real

Harvard administrators said Passio relies on “internal hardware installed in each shuttle,” so a change needed a summer window. Harrisonburg physically removed Passio GPS units. Operator-held contracts also mean the school cannot always swap the app without re-bidding the bus vendor. That is Passio’s moat, and a procurement headache for a software-only challenger unless you ride in on a new operator, a summer hardware swap, or a feed the school already owns.

### GTFS / GTFS-RT is the wedge

TripShot, Peak Transit, TransLoc, Swiftly, and the Transit app all emphasize standard feeds. If a campus publishes a solid GTFS-RT stream, Transit or Citymapper can become the rider app without a new AVL box, and student developers can build better ETAs (already happening at Rutgers). Passio has talked about a public API, but campuses have also said outages in Passio take every dependent app down.

### White space

Tied to verified complaints and buying behavior, not speculation piled on speculation:

- A rider app that is actually trusted on ETAs, ghost buses, and stop-first UX, which is where Passio keeps losing student sentiment even when staff like the back-end data (NCSU is the clearest example).
- Hardware-optional or standards-based AVL, so schools are not locked to a summer rip-and-replace — the objection that killed Harvard’s student-app plan and delayed every Passio exit.
- A public, stable feed so you can coexist with Transit, Google Maps, and student apps instead of fighting them.
- Selling to the university (or a coop) rather than only to Transdev/LAZ, so the rider experience is not an afterthought in an operations bundle.
- Accessibility and a feedback form that actually sends (recurring Passio review themes).
- Do not assume “leaving Passio” means leaving Transit Technologies — TripShot is the in-house alternative. A new entrant is competing with a PE portfolio that can offer Passio, TripShot, TripMaster, and Ecolane under one coop contract.
- Support quality is a real differentiator: NCSU left TransLoc after 16 months without a rep; Harrisonburg left Passio for “vendor relationship” and faster feedback; ETA’s campus pitch is “stress-free implementation” and a live human.
- Price: mid-size deals appear to land in the low-to-mid five figures per year after Year 1 hardware, or about $10k/month at a large campus like Rutgers (2023, with the Targum 403 caveat). Beating Passio on price alone did not win The Woodlands; rider experience plus an easier switch is the sharper opening.
