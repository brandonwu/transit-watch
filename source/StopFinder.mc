import Toybox.Lang;
import Toybox.Math;

// A stop from StopData paired with where the rider is standing.
(:glance)
class NearbyStop {
    var name as String;
    var meters as Float;
    var bearing as Number; // Degrees clockwise from true north.

    function initialize(stopName as String, distance as Float, heading as Number) {
        name = stopName;
        meters = distance;
        bearing = heading;
    }
}

// Nearest-stop search over the generated StopData table.
//
// Muni Metro fits in a few miles of coastline, so the flat-earth
// approximation is accurate to well under a stop spacing and costs a
// single cosine instead of 129 haversines.
(:glance)
module StopFinder {
    // Ground distance of one StopData unit (1e-5 degrees) of latitude.
    const METERS_PER_UNIT = 1.1132;
    // Past this the rider is not in San Francisco and no stop is useful.
    const MAX_METERS = 80000.0;
    const COMPASS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"] as Array<String>;

    function nearest(latitude as Double, longitude as Double) as NearbyStop? {
        var stops = nearestStops(latitude, longitude, 1);
        return stops.size() > 0 ? stops[0] : null;
    }

    // The `wanted` closest stops, nearest first, dropping anything beyond
    // MAX_METERS. Keeps only `wanted` candidates alive while scanning so a
    // glance never allocates 129 objects.
    function nearestStops(latitude as Double, longitude as Double,
                          wanted as Number) as Array<NearbyStop> {
        var cosLatitude = Math.cos(latitude * Math.PI / 180.0);
        var latUnits = latitude * StopData.SCALE;
        var lonUnits = longitude * StopData.SCALE;
        var bestIndex = new [wanted] as Array<Number>;
        var bestSquare = new [wanted] as Array<Double>;
        var found = 0;

        for (var i = 0; i < StopData.COUNT; i++) {
            var north = (StopData.LATS[i] - latUnits) * METERS_PER_UNIT;
            var east = (StopData.LONS[i] - lonUnits) * METERS_PER_UNIT * cosLatitude;
            var square = (north * north) + (east * east);
            if (found == wanted && square >= bestSquare[wanted - 1]) { continue; }

            var slot = found < wanted ? found : wanted - 1;
            while (slot > 0 && bestSquare[slot - 1] > square) {
                bestSquare[slot] = bestSquare[slot - 1];
                bestIndex[slot] = bestIndex[slot - 1];
                slot--;
            }
            bestSquare[slot] = square;
            bestIndex[slot] = i;
            if (found < wanted) { found++; }
        }

        var stops = [] as Array<NearbyStop>;
        for (var i = 0; i < found; i++) {
            if (bestSquare[i] > MAX_METERS * MAX_METERS) { break; }
            var index = bestIndex[i];
            var north = StopData.LATS[index] - latUnits;
            var east = (StopData.LONS[index] - lonUnits) * cosLatitude;
            stops.add(new NearbyStop(StopData.NAMES[index],
                                     Math.sqrt(bestSquare[i]).toFloat(),
                                     bearing(north, east)));
        }
        return stops;
    }

    function bearing(north as Double, east as Double) as Number {
        var degrees = Math.toDegrees(Math.atan2(east, north));
        if (degrees < 0.0) { degrees += 360.0; }
        return degrees.toNumber() % 360;
    }

    // Nearest of the eight compass points; the doubling keeps the 22.5
    // degree boundaries exact in integer arithmetic.
    function compass(degrees as Number) as String {
        return COMPASS[(((degrees * 2) + 45) / 90) % 8];
    }

    // "0.3mi", "480ft", "1.2km", "450m" -- short enough to sit beside a
    // stop name on a 164 pixel glance.
    function formatDistance(meters as Float, statute as Boolean) as String {
        if (statute) {
            var feet = meters * 3.28084;
            if (feet < 528.0) { return roundTo(feet, 10) + "ft"; }
            return trim(meters / 1609.344) + "mi";
        }
        if (meters < 1000.0) { return roundTo(meters, 10) + "m"; }
        return trim(meters / 1000.0) + "km";
    }

    // "Embarcadero - 0.3mi N"
    function describe(stop as NearbyStop, statute as Boolean) as String {
        return stop.name + " - " + detail(stop, statute);
    }

    // "0.3mi N"
    function detail(stop as NearbyStop, statute as Boolean) as String {
        return formatDistance(stop.meters, statute) + " " + compass(stop.bearing);
    }

    function roundTo(value as Float, step as Number) as String {
        return ((value / step + 0.5).toNumber() * step).toString();
    }

    function trim(value as Float) as String {
        if (value < 10.0) { return value.format("%.1f"); }
        return (value + 0.5).toNumber().toString();
    }
}
