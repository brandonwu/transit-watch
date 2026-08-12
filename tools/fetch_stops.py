#!/usr/bin/env python3
"""Generate source/StopData.mc from the 511.org stop places feed.

Downloads every SFMTA stop place, keeps the ones tagged TransportMode
urbanRail (Muni Metro light rail, including the T Third and the Central
Subway), normalizes the display names, merges the directional pairs that
share a platform, and writes a Monkey C table of names and coordinates.

Usage:
    python3 tools/fetch_stops.py [--cache data/stopplaces.json]
"""

import argparse
import gzip
import json
import math
import re
import sys
import urllib.request
from pathlib import Path

API_URL = (
    "https://api.511.org/transit/stopplaces"
    "?api_key={key}&operator_id=SF&format=json"
)
DEFAULT_KEY = "ec689fa2-8074-4838-9f52-7772f82247b2"

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "data" / "stopplaces.json"
OUTPUT = ROOT / "source" / "StopData.mc"

# Stops closer than this and sharing a name are the two directions of one
# platform pair, so they collapse to a single entry at their midpoint.
MERGE_METERS = 500.0
# A station swallows the unnamed street stops around its entrances, so
# standing at Powell reads "Powell" rather than "Market & 5th".
STATION_METERS = 150.0
# Two street stops this close are the same corner recorded twice, such as
# "4th St & King St" and "King St & 4th St".
CORNER_METERS = 40.0
STATION_WORDS = re.compile(r"\bStation\b|\bBART\b|^Metro\s", re.IGNORECASE)

# Whole names that the generic rules cannot shorten sensibly.
ALIASES = {
    "Union Square/Market St": "Union Square",
    "Chinatown - Rose Pak": "Chinatown",
    "Yerba Buena/Moscone": "Yerba Buena",
    "San Jose Ave/Glen Park": "Glen Park",
    "Balboa Park BART/Mezzanine Level": "Balboa Park",
    "Judah/La Playa/Ocean Beach": "Ocean Beach",
    "Ocean Ave/Ccsf Pedestrian Bridge": "CCSF",
    "West Portal/Sloat/St Francis Circle": "St Francis Cir",
    "Duboce St/Noe St/Duboce Park": "Duboce & Noe",
    "Wawona/46th Ave /Sf Zoo": "SF Zoo",
    "Don Chee Way/Steuart St": "Don Chee Way",
    "Ucsf / Chase Center (16th St)": "UCSF Chase Ctr",
    "Ucsf / Chase Center (16th Street)": "UCSF Chase Ctr",
    "Ucsf Medical Center (Mariposa)": "UCSF Med Ctr",
    "The Embarcadero & Ferry Building": "Ferry Building",
    "Sunset Tunnel East Portal": "Sunset Tunnel",
    "Third Street/Gilman/Paul": "3rd & Gilman",
    "Third Street/Hudson/Innes": "3rd & Hudson",
    "Third Street/Kirkwood/La Salle": "3rd & Kirkwood",
    "Third Street/Oakdale/Palou": "3rd & Oakdale",
    "Third Street/Revere/Shafter": "3rd & Revere",
}

# Directional and platform suffixes that carry no information once the
# two directions of a stop are merged.
DIRECTION_SUFFIX = re.compile(
    r"[\s/](?:Downtown|Downtn|Outbound|Outbd|Inbound|Inbd"
    r"|Northbound|Southbound|Eastbound|Westbound)$",
    re.IGNORECASE,
)
STATION_SUFFIX = re.compile(r"\s+(?:Station|Sta)$", re.IGNORECASE)
STREET_TYPE = re.compile(
    r"\s+(?:St|Ave|Aves|Blvd|Dr|Rd|Ter|Way|Ln|Pl|Ct|Hwy)$", re.IGNORECASE
)
# Long street names that read fine shortened.
STREET_RENAMES = [
    (re.compile(r"^Third Street\b", re.IGNORECASE), "3rd St"),
    (re.compile(r"^Fourth Street\b", re.IGNORECASE), "4th St"),
    (re.compile(r"^Right Of Way/", re.IGNORECASE), ""),
    (re.compile(r"^The Embarcadero\b"), "Embarcadero"),
]
CAPS = {"Ucsf": "UCSF", "Ccsf": "CCSF", "Sf": "SF", "Bart": "BART"}


def fetch(cache: Path, key: str) -> dict:
    if not cache.exists():
        url = API_URL.format(key=key)
        sys.stderr.write("downloading %s\n" % url.split("?")[0])
        with urllib.request.urlopen(url) as response:
            raw = response.read()
        if raw[:2] == b"\x1f\x8b":
            raw = gzip.decompress(raw)
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_text(raw.decode("utf-8-sig"), encoding="utf-8")
    return json.loads(cache.read_text(encoding="utf-8"))


def light_rail_stops(feed: dict) -> list:
    places = feed["Siri"]["ServiceDelivery"]["DataObjectDelivery"]["dataObjects"][
        "SiteFrame"
    ]["stopPlaces"]["StopPlace"]
    stops = []
    for place in places:
        if place.get("TransportMode") != "urbanRail":
            continue
        location = place.get("Centroid", {}).get("Location") or {}
        if not location.get("Latitude") or not location.get("Longitude"):
            continue
        raw = place["Name"].strip()
        stops.append(
            {
                "raw": raw,
                "name": normalize(raw),
                "station": bool(STATION_WORDS.search(raw)),
                "lat": float(location["Latitude"]),
                "lon": float(location["Longitude"]),
            }
        )
    return stops


def normalize(name: str) -> str:
    """Turn a feed name such as "Metro Embarcadero Station" into "Embarcadero"."""
    name = re.sub(r"\s+", " ", name).strip()
    if name in ALIASES:
        return ALIASES[name]

    # "Metro Castro Station/Downtown" -> "Castro"
    name = re.sub(r"^Metro\s+", "", name)
    previous = None
    while previous != name:
        previous = name
        name = DIRECTION_SUFFIX.sub("", name).strip()
        name = STATION_SUFFIX.sub("", name).strip()
    if name in ALIASES:
        return ALIASES[name]

    for pattern, replacement in STREET_RENAMES:
        name = pattern.sub(replacement, name).strip()

    # "Judah St & 9th Ave" -> "Judah & 9th". A lone street keeps its type so
    # that it still reads as a place: "Liberty St", not "Liberty".
    if "&" in name:
        parts = [STREET_TYPE.sub("", part.strip()).strip() for part in name.split("&")]
        name = " & ".join(part for part in parts if part)

    words = [CAPS.get(word, word) for word in name.split(" ")]
    name = " ".join(words)
    return ALIASES.get(name, name)


def meters_between(a: dict, b: dict) -> float:
    mean_lat = math.radians((a["lat"] + b["lat"]) / 2.0)
    dx = (a["lon"] - b["lon"]) * math.cos(mean_lat)
    dy = a["lat"] - b["lat"]
    return math.hypot(dx, dy) * 111320.0


def collapse(cluster: list) -> dict:
    """Reduce a group of feed records to one stop at their midpoint.

    Station records win the label; otherwise the name backed by the most
    records wins, then a cross street over a lone street, then the
    shortest, then the alphabetically first.
    """
    station = any(stop["station"] for stop in cluster)
    candidates = [stop for stop in cluster if stop["station"] == station]
    counts = {}
    for stop in candidates:
        counts[stop["name"]] = counts.get(stop["name"], 0) + 1
    name = sorted(counts, key=lambda n: (-counts[n], "&" not in n, len(n), n))[0]
    return {
        "name": name,
        "station": station,
        "lat": sum(s["lat"] for s in cluster) / len(cluster),
        "lon": sum(s["lon"] for s in cluster) / len(cluster),
        "sources": sorted({s["raw"] for s in cluster}),
        "members": cluster,
    }


def merge(stops: list) -> list:
    """Collapse the feed's per-direction, per-corner records into stops.

    Two passes: same-named records within MERGE_METERS are the two
    directions of one stop, then differently named neighbours are joined
    when a station is close enough to own them or when two street records
    describe the same corner.
    """
    named = []
    for stop in sorted(stops, key=lambda s: (s["name"], s["lat"], s["lon"])):
        for cluster in named:
            if cluster[0]["name"] == stop["name"] and meters_between(
                cluster[0], stop
            ) <= MERGE_METERS:
                cluster.append(stop)
                break
        else:
            named.append([stop])

    groups = [collapse(cluster) for cluster in named]
    groups.sort(key=lambda g: (not g["station"], g["name"]))

    merged = []
    for group in groups:
        for other in merged:
            limit = (
                STATION_METERS
                if (group["station"] or other["station"])
                else CORNER_METERS
            )
            if meters_between(group, other) <= limit:
                other.update(collapse(other["members"] + group["members"]))
                break
        else:
            merged.append(group)

    for stop in merged:
        del stop["members"]
    return sorted(merged, key=lambda s: (-s["lat"], s["lon"]))


def render(stops: list, source_count: int) -> str:
    names = ",\n        ".join(
        '"%s"' % stop["name"].replace('"', '\\"') for stop in stops
    )
    lats = ", ".join(str(round(stop["lat"] * 1e5)) for stop in stops)
    lons = ", ".join(str(round(stop["lon"] * 1e5)) for stop in stops)

    def wrap(values: str) -> str:
        out, line = [], "        "
        for token in values.split(" "):
            if len(line) + len(token) > 88:
                out.append(line.rstrip())
                line = "        "
            line += token + " "
        out.append(line.rstrip())
        return "\n".join(out)

    return TEMPLATE.format(
        count=len(stops),
        source_count=source_count,
        names=names,
        lats=wrap(lats),
        lons=wrap(lons),
    )


TEMPLATE = '''// Generated by tools/fetch_stops.py -- do not edit by hand.
//
// San Francisco Muni Metro light rail stops from the 511.org stop places
// feed (operator SF, TransportMode urbanRail). {source_count} feed records
// collapse into {count} stops once the directional pairs are merged.
//
// Latitudes and longitudes are degrees scaled by 100000 and stored as
// Numbers so the table stays cheap enough to scan inside a glance.
import Toybox.Lang;

(:glance)
module StopData {{
    const SCALE = 100000.0;
    const COUNT = {count};

    const NAMES as Array<String> = [
        {names}
    ];

    const LATS as Array<Number> = [
{lats}
    ];

    const LONS as Array<Number> = [
{lons}
    ];
}}
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, default=CACHE)
    parser.add_argument("--api-key", default=DEFAULT_KEY)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument(
        "--list", action="store_true", help="print the normalized stops and exit"
    )
    args = parser.parse_args()

    stops = light_rail_stops(fetch(args.cache, args.api_key))
    merged = merge(stops)

    if args.list:
        for stop in merged:
            print(
                "%-18s %9.5f %11.5f  <- %s"
                % (stop["name"], stop["lat"], stop["lon"], "; ".join(stop["sources"]))
            )
        print("%d feed records -> %d stops" % (len(stops), len(merged)))
        return 0

    args.output.write_text(render(merged, len(stops)), encoding="utf-8")
    sys.stderr.write(
        "wrote %s (%d feed records -> %d stops)\n"
        % (args.output, len(stops), len(merged))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
