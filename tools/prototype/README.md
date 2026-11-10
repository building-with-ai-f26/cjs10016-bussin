# Prototype build tools

These files rebuild [docs/prototype/index.html](../../docs/prototype/index.html), the interactive HTML prototype. The prototype is one self-contained file: the template below with the map and route data inlined.

- `build_proto.py` turns OpenStreetMap streets and Passio route data into map data (streets, parks, water, labels, routes, stops, and each stop's distance along its route).
- `proto_template.html` is the prototype page. Its `__DATA__` placeholder gets replaced with that map data.
- `data/passio-stops.json` and `data/passio-routes.json` are a snapshot of NYU's Passio GO feed (system 1007) taken on Nov 8, 2026.

## Rebuild

1. Download the OpenStreetMap data (about 7 MB, so it isn't committed):

   ```bash
   curl -s -A "bussin-class-prototype" https://overpass-api.de/api/interpreter \
     --data-urlencode 'data=[out:json][timeout:120];(way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|unclassified|living_street|pedestrian)$"](40.686,-74.016,40.750,-73.966);way["leisure"="park"](40.686,-74.016,40.750,-73.966);way["natural"="coastline"](40.67,-74.04,40.77,-73.94););out geom;' \
     -o /tmp/osm.json
   ```

2. Build the map data and inject it into the template:

   ```bash
   python3 tools/prototype/build_proto.py /tmp/osm.json tools/prototype/data/passio-stops.json /tmp/protodata.json
   python3 -c "t=open('tools/prototype/proto_template.html').read(); d=open('/tmp/protodata.json').read(); open('docs/prototype/index.html','w').write(t.replace('__DATA__', d))"
   ```

## Refresh the Passio snapshot

```bash
curl -s "https://passio3.com/www/mapGetData.php?getStops=2" --data-urlencode 'json={"s0":"1007","sA":1}' -o tools/prototype/data/passio-stops.json
curl -s "https://passio3.com/www/mapGetData.php?getRoutes=2" --data-urlencode 'json={"systemSelected0":"1007","amount":1}' -o tools/prototype/data/passio-routes.json
```

The feed answers without a login. We still need to confirm that Passio allows a third-party app to use it.

## Test links

The prototype accepts a few URL parameters for testing: `?view=plan&key=tandon`, `?view=route&id=74769`, `?view=stop&id=6574`, `?view=bus&num=2146`, `?view=search&q=lang`, `?theme=dark`, and `?instant` (skip camera animations, useful for screenshots).
