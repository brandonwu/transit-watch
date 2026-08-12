import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Stands in for a Dc so the layout tests can run without a screen. Text is
// six pixels per character, which is close enough to Instinct's small fonts
// to exercise the fitting rules.
class RecordingDc {
    var operations as Number = 0;

    function setColor(foreground, background) as Void { operations++; }
    function clear() as Void { operations++; }
    function setClip(x, y, width, height) as Void { operations++; }
    function clearClip() as Void { operations++; }
    function drawText(x, y, font, text, justification) as Void { operations++; }
    function fillCircle(x, y, radius) as Void { operations++; }
    function fillPolygon(points) as Void { operations++; }
    function fillRectangle(x, y, width, height) as Void { operations++; }
    function drawRectangle(x, y, width, height) as Void { operations++; }
    function drawLine(x1, y1, x2, y2) as Void { operations++; }
    function getWidth() as Number { return 176; }
    function getHeight() as Number { return 176; }
    function getFontHeight(font) as Number { return 20; }
    function getTextWidthInPixels(text, font) as Number {
        return text.toString().length() * 6;
    }
}

// Metro Embarcadero Station.
const EMBARCADERO_LATITUDE = 37.79294d;
const EMBARCADERO_LONGITUDE = -122.39674d;

(:test)
function testStopTableIsPopulated(logger) {
    return StopData.COUNT == StopData.NAMES.size() &&
           StopData.COUNT == StopData.LATS.size() &&
           StopData.COUNT == StopData.LONS.size() &&
           StopData.COUNT > 100;
}

(:test)
function testNamesAreNormalized(logger) {
    for (var i = 0; i < StopData.COUNT; i++) {
        var name = StopData.NAMES[i];
        if (name.length() == 0 || name.length() > 24) {
            logger.debug("bad name: " + name);
            return false;
        }
        if (name.find("Metro ") != null || name.find("Station") != null) {
            logger.debug("unnormalized name: " + name);
            return false;
        }
    }
    return true;
}

(:test)
function testNearestStopAtEmbarcadero(logger) {
    var stop = StopFinder.nearest(EMBARCADERO_LATITUDE, EMBARCADERO_LONGITUDE);
    if (stop == null) { return false; }
    logger.debug(StopFinder.describe(stop, true));
    return stop.name.equals("Embarcadero") && stop.meters < 25.0;
}

// A block down Market from the Market & 1st stop, which sits northeast.
(:test)
function testDistanceAndBearingFromMarketStreet(logger) {
    var stop = StopFinder.nearest(37.79028d, -122.40023d);
    if (stop == null) { return false; }
    logger.debug(StopFinder.describe(stop, true));
    return stop.name.equals("Market & 1st") &&
           stop.meters > 100.0 && stop.meters < 130.0 &&
           StopFinder.compass(stop.bearing).equals("NE");
}

(:test)
function testNearestStopsAreOrderedAndDistinct(logger) {
    var stops = StopFinder.nearestStops(EMBARCADERO_LATITUDE, EMBARCADERO_LONGITUDE, 5);
    if (stops.size() != 5) { return false; }
    for (var i = 1; i < stops.size(); i++) {
        if (stops[i].meters < stops[i - 1].meters) { return false; }
        if (stops[i].name.equals(stops[i - 1].name)) { return false; }
    }
    return true;
}

(:test)
function testNoStopFarFromSanFrancisco(logger) {
    // Sacramento.
    return StopFinder.nearest(38.5816d, -121.4944d) == null;
}

(:test)
function testCompassPoints(logger) {
    return StopFinder.compass(0).equals("N") &&
           StopFinder.compass(22).equals("N") &&
           StopFinder.compass(23).equals("NE") &&
           StopFinder.compass(180).equals("S") &&
           StopFinder.compass(292).equals("W") &&
           StopFinder.compass(293).equals("NW") &&
           StopFinder.compass(337).equals("NW") &&
           StopFinder.compass(338).equals("N") &&
           StopFinder.compass(359).equals("N");
}

(:test)
function testDistanceFormatting(logger) {
    return StopFinder.formatDistance(483.0, true).equals("0.3mi") &&
           StopFinder.formatDistance(100.0, true).equals("330ft") &&
           StopFinder.formatDistance(24140.0, true).equals("15mi") &&
           StopFinder.formatDistance(450.0, false).equals("450m") &&
           StopFinder.formatDistance(1200.0, false).equals("1.2km");
}

(:test)
function testGlanceLine(logger) {
    var stop = new NearbyStop("Embarcadero", 483.0, 10);
    var line = StopFinder.describe(stop, true);
    logger.debug(line);
    return line.equals("Embarcadero - 0.3mi N");
}

(:test)
function testLongNameIsClippedButDistanceSurvives(logger) {
    var dc = new RecordingDc();
    var line = TextFit.clip(dc as Graphics.Dc, "Embarcadero & Washington", " - 0.3mi N",
                            Graphics.FONT_TINY, 120);
    logger.debug(line);
    return line.length() * 6 <= 120 && line.find(" - 0.3mi N") != null &&
           line.find("..") != null;
}

(:test)
function testShortNameIsLeftAlone(logger) {
    var dc = new RecordingDc();
    return TextFit.clip(dc as Graphics.Dc, "Castro", " - 0.3mi N", Graphics.FONT_TINY, 120).equals("Castro - 0.3mi N");
}

(:test)
function testNameWrapsAtASpace(logger) {
    var dc = new RecordingDc();
    var lines = TextFit.wrap(dc as Graphics.Dc, "Embarcadero & Washington", Graphics.FONT_TINY, 90);
    logger.debug(lines.toString());
    return lines.size() == 2 && lines[0].equals("Embarcadero &") &&
           lines[1].equals("Washington");
}

(:test)
function testAppScreenRenders(logger) {
    var dc = new RecordingDc();
    MuniRenderer.draw(dc as Graphics.Dc, new NearbyStop("Embarcadero", 483.0, 10),
                      "GPS fix", true);
    return dc.operations >= 8;
}

(:test)
function testAppScreenRendersWithoutAStop(logger) {
    var dc = new RecordingDc();
    MuniRenderer.draw(dc as Graphics.Dc, null, "Waiting for GPS", true);
    return dc.operations >= 5;
}

(:test)
function testArrowPointsAtTheBearing(logger) {
    // Due east: the tip should be to the right of the center and level.
    var points = MuniRenderer.arrow(50, 50, 20, 90);
    logger.debug(points.toString());
    return points.size() == 4 && points[0][0] == 70 && points[0][1] == 50;
}
