"""Build an Apple Maps-style SVG of the NYU area from OSM + Passio data.
Usage: python3 -I build_map.py <osm.json> <stops.json> <out_fragment.json>
"""
import json, math, sys

osm_path, stops_path, out_path = sys.argv[1:4]

LAT0, LNG0 = 40.7300, -73.9930            # projection center
PX_PER_M = 0.26
M_PER_DEG_LAT = 111_320
M_PER_DEG_LNG = 111_320 * math.cos(math.radians(LAT0))
# canvas bounds (geographic)
N, S, W, E = 40.7500, 40.6880, -74.0160, -73.9660

def proj(lat, lng):
    x = (lng - W) * M_PER_DEG_LNG * PX_PER_M
    y = (N - lat) * M_PER_DEG_LAT * PX_PER_M
    return x, y

CW, CH = proj(S, E)
CW, CH = round(CW), round(CH)

def path_d(coords, close=False):
    pts = [proj(la, ln) for la, ln in coords]
    out, last = [], None
    for i, (x, y) in enumerate(pts):
        p = (round(x, 1), round(y, 1))
        if p == last:
            continue
        out.append(("M" if not out else "L") + f"{p[0]} {p[1]}")
        last = p
    if close:
        out.append("Z")
    return "".join(out)

osm = json.load(open(osm_path))
roads = {k: [] for k in ["motorway", "major", "tertiary", "minor", "ped"]}
parks, coast = [], []
named = {}
CLASS = {"motorway": "motorway", "trunk": "motorway", "primary": "major", "secondary": "major",
         "tertiary": "tertiary", "residential": "minor", "unclassified": "minor",
         "living_street": "minor", "pedestrian": "ped"}

def abbreviate(n):
    rep = [("Street", "St"), ("Avenue", "Ave"), ("Place", "Pl"), ("Boulevard", "Blvd"),
           ("Drive", "Dr"), ("East ", "E "), ("West ", "W "), ("South", "S"), ("North", "N")]
    for a, b in rep:
        n = n.replace(a, b)
    return n

for el in osm["elements"]:
    if el["type"] != "way" or "geometry" not in el:
        continue
    t = el.get("tags", {})
    coords = [(g["lat"], g["lon"]) for g in el["geometry"]]
    if t.get("natural") == "coastline":
        coast.append((el["nodes"], coords))
    elif t.get("leisure") == "park":
        if el["nodes"][0] == el["nodes"][-1]:
            parks.append(path_d(coords, close=True))
    elif t.get("highway") in CLASS:
        if t.get("tunnel") == "yes" or t.get("area") == "yes":
            continue
        c = CLASS[t["highway"]]
        roads[c].append(path_d(coords))
        if c in ("major", "tertiary", "motorway") and t.get("name"):
            named.setdefault(abbreviate(t["name"]), []).append(coords)

# --- stitch coastline into chains -------------------------------------------
chains = [list(zip(n, c)) for n, c in coast]
merged = True
while merged:
    merged = False
    for i in range(len(chains)):
        for j in range(len(chains)):
            if i != j and chains[i][-1][0] == chains[j][0][0]:
                chains[i] = chains[i] + chains[j][1:]
                del chains[j]
                merged = True
                break
        if merged:
            break

BIG = (-74.10, 40.65, -73.88, 40.80)  # minlng, minlat, maxlng, maxlat

def perim_param(lat, lng):
    """Position along big-box perimeter, counterclockwise from SE corner."""
    x0, y0, x1, y1 = BIG
    w, h = x1 - x0, y1 - y0
    d = {"E": x1 - lng, "N": y1 - lat, "W": lng - x0, "S": lat - y0}
    side = min(d, key=d.get)
    if side == "E": return (lat - y0) / h, (lat, x1)
    if side == "N": return 1 + (x1 - lng) / w, (y1, lng)
    if side == "W": return 2 + (y1 - lat) / h, (lat, x0)
    return 3 + (lng - x0) / w, (y0, lng)

CORNERS = [(1, (BIG[3], BIG[2])), (2, (BIG[3], BIG[0])), (3, (BIG[1], BIG[0])), (4, (BIG[1], BIG[2]))]

land = []
for ch in chains:
    coords = [c for _, c in ch]
    if ch[0][0] == ch[-1][0]:
        land.append(path_d(coords, close=True))
        continue
    te, pe = perim_param(*coords[-1])
    ts, ps = perim_param(*coords[0])
    ring = coords + [pe]
    t = te
    if ts < te:
        ts += 4
    for k in range(2):  # walk corners CCW from end to start
        for cp, cc in CORNERS:
            cp += 4 * k
            if t < cp < ts:
                ring.append(cc)
    ring.append(ps)
    land.append(path_d(ring, close=True))

# --- street labels ----------------------------------------------------------
WANT = ["Broadway", "Lafayette St", "3rd Ave", "1st Ave", "2nd Ave", "E 14th St", "W 14th St",
        "W 4th St", "E Houston St", "W Houston St", "Bowery", "6th Ave", "Ave of the Americas",
        "7th Ave S", "5th Ave", "E 23rd St", "Park Ave S", "Hudson St", "Bleecker St",
        "Ave A", "Ave C", "Canal St", "Delancey St", "University Pl", "Irving Pl", "Lexington Ave",
        "Varick St", "Christopher St", "8th Ave", "E 34th St", "W 23rd St"]
labels = []
for name, ways in named.items():
    if name not in WANT:
        continue
    placed = []
    segs = []
    for coords in ways:
        pts = [proj(*c) for c in coords]
        # walk the way, emitting maximal near-straight runs
        i = 0
        while i < len(pts) - 1:
            j = i + 1
            while j + 1 < len(pts):
                run = sum(math.dist(p, q) for p, q in zip(pts[i:j + 2], pts[i + 1:j + 2]))
                if math.dist(pts[i], pts[j + 1]) < 0.985 * run:
                    break
                j += 1
            L = math.dist(pts[i], pts[j])
            if L > 60:
                segs.append((L, pts[i], pts[j]))
            i = j
    segs.sort(reverse=True)
    for L, a, b in segs:
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if not (20 < mx < CW - 20 and 20 < my < CH - 20):
            continue
        if any(math.dist((mx, my), p) < 380 for p in placed):
            continue
        ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
        if ang > 90: ang -= 180
        if ang <= -90: ang += 180
        placed.append((mx, my))
        labels.append({"t": "Ave of the Americas" if name == "6th Ave" else name,
                       "x": round(mx, 1), "y": round(my, 1), "a": round(ang, 1)})
        if len(placed) >= 3:
            break

# --- Passio routes + stops --------------------------------------------------
s = json.load(open(stops_path))
ROUTES = ["74773", "74771", "74772", "74768", "74770", "74774", "74769"]  # draw order (A on top)
routes = []
stop_xy = {}
stop_routes = {}

def stop_coord(sid):
    st = s["stops"]["ID" + sid]
    return proj(st["latitude"], st["longitude"])

worst = 0
for rid in ROUTES:
    name, color = s["routes"][rid][0], s["routes"][rid][1]
    ll = [(float(p["lat"]), float(p["lng"])) for seg in s["routePoints"][rid] for p in seg]
    pts = [proj(*p) for p in ll]
    cum = [0.0]
    for a, b in zip(pts, pts[1:]):
        cum.append(cum[-1] + math.dist(a, b))
    L = cum[-1]
    seq, prev = [], -1.0
    entries = s["routes"][rid][2:]
    for k, x in enumerate(entries):
        sid = x[1]
        px, py = stop_coord(sid)
        best = None
        for i in range(len(pts) - 1):
            if cum[i + 1] < prev:
                continue
            (ax, ay), (bx, by) = pts[i], pts[i + 1]
            seg = cum[i + 1] - cum[i]
            t = 0 if seg == 0 else max(0, min(1, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / seg ** 2))
            qx, qy = ax + (bx - ax) * t, ay + (by - ay) * t
            d = cum[i] + seg * t
            if d < prev:
                continue
            perp = math.dist((px, py), (qx, qy))
            score = perp + 0.02 * (d - max(prev, 0))
            if best is None or score < best[0]:
                best = (score, d, perp)
        if k == len(entries) - 1 and sid == entries[0][1]:
            best = (0, L, 0)        # loop closes at its first stop
        worst = max(worst, best[2])
        seq.append({"id": sid, "d": round(best[1], 1)})
        prev = best[1]
        stop_xy[sid] = stop_coord(sid)
        stop_routes.setdefault(sid, [])
        if rid not in stop_routes[sid]:
            stop_routes[sid].append(rid)
    routes.append({"id": rid, "name": name, "color": color, "d": path_d(ll),
                   "pts": [[round(v, 1) for v in p] for p in pts], "len": round(L, 1), "stops": seq})
print("max stop-to-route distance px", round(worst, 1))

stops = []
for sid, (x, y) in stop_xy.items():
    nm = s["stops"]["ID" + sid]["name"]
    stops.append({"id": sid, "name": nm, "x": round(x, 1), "y": round(y, 1), "routes": stop_routes[sid]})

PLACES = [  # (label, lat, lng, kind)
    ("GREENWICH VILLAGE", 40.7338, -74.0012, "hood"), ("EAST VILLAGE", 40.7270, -73.9830, "hood"),
    ("SOHO", 40.7234, -74.0010, "hood"), ("NOHO", 40.7272, -73.9935, "hood"),
    ("GRAMERCY", 40.7378, -73.9845, "hood"), ("FLATIRON", 40.7415, -73.9905, "hood"),
    ("LOWER EAST SIDE", 40.7170, -73.9855, "hood"), ("CHELSEA", 40.7455, -74.0005, "hood"),
    ("WEST VILLAGE", 40.7350, -74.0065, "hood"), ("KIPS BAY", 40.7425, -73.9790, "hood"),
    ("ALPHABET CITY", 40.7250, -73.9770, "hood"), ("NOLITA", 40.7225, -73.9955, "hood"),
    ("CHINATOWN", 40.7160, -73.9975, "hood"), ("TRIBECA", 40.7170, -74.0085, "hood"),
    ("CIVIC CENTER", 40.7135, -74.0035, "hood"), ("TWO BRIDGES", 40.7110, -73.9930, "hood"),
    ("DUMBO", 40.7030, -73.9885, "hood"), ("BROOKLYN HEIGHTS", 40.6960, -73.9960, "hood"),
    ("DOWNTOWN\nBROOKLYN", 40.6915, -73.9855, "hood"), ("FINANCIAL DISTRICT", 40.7075, -74.0090, "hood"),
    ("Washington\nSquare Park", 40.7310, -73.9976, "park"), ("Union Square", 40.7357, -73.9908, "park"),
    ("Tompkins\nSquare Park", 40.7265, -73.9817, "park"), ("Stuyvesant Town", 40.7317, -73.9775, "park"),
    ("Hudson River", 40.7330, -74.0125, "water"), ("East River", 40.7200, -73.9705, "water"),
]
places = []
for label, la, ln, kind in PLACES:
    x, y = proj(la, ln)
    places.append({"t": label, "x": round(x, 1), "y": round(y, 1), "k": kind})

# Searchable destinations (approximate building locations)
DEST = [
    ("tandon", "NYU Tandon School of Engineering", "6 MetroTech Center, Brooklyn", 40.6942, -73.9865, "school"),
    ("langone", "NYU Langone Health", "550 First Ave", 40.7421, -73.9740, "hospital"),
    ("gramercy", "Gramercy Green", "NYU residence hall · 3rd Ave & 23rd St", 40.7395, -73.9830, "home"),
    ("palladium", "Palladium Hall", "140 E 14th St", 40.7333, -73.9883, "building"),
    ("thirdnorth", "Third Avenue North", "75 Third Ave", 40.7313, -73.9887, "building"),
    ("stuytown", "Stuyvesant Town", "Avenue C & 16th St", 40.7303, -73.9752, "building"),
    ("unionsq", "Union Square", "Park", 40.7359, -73.9911, "park"),
    ("westvillage", "Morton & Greenwich", "West Village", 40.7313, -74.0068, "building"),
    ("soho", "Broadway & Broome St", "SoHo", 40.7213, -73.9998, "shop"),
    ("cadman", "Cadman Plaza", "Brooklyn Heights", 40.6975, -73.9905, "park"),
]
dests = []
for key, name, sub, la, ln, icon in DEST:
    x, y = proj(la, ln)
    dests.append({"key": key, "name": name, "sub": sub, "x": round(x, 1), "y": round(y, 1), "icon": icon})

me = proj(40.72915, -73.99645)   # near NYU Stern, 44 W 4th St
out = {
    "w": CW, "h": CH, "pxPerM": PX_PER_M,
    "land": land, "parks": parks,
    "roads": {k: "".join(v) for k, v in roads.items()},
    "labels": labels, "places": places,
    "routes": routes, "stops": stops, "dests": dests,
    "me": [round(me[0], 1), round(me[1], 1)],
}
json.dump(out, open(out_path, "w"), separators=(",", ":"))
print("canvas", CW, CH, "land", len(land), "parks", len(parks), "labels", len(labels),
      "stops", len(stops), "bytes", len(json.dumps(out, separators=(",", ":"))))
for r in routes:
    print(r["name"], "len px", r["len"], "≈ km", round(r["len"] / PX_PER_M / 1000, 1), [x["d"] for x in r["stops"]])
