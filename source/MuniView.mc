import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.WatchUi;

// Draws the app screen. Split out from the view so the unit tests can
// render into an off-screen device context.
module MuniRenderer {
    const HEADER_HEIGHT = 46;
    const CONTENT_WIDTH = 150;
    const NAME_BOTTOM = 116;
    const DETAIL_Y = 120;
    const STATUS_Y = 152;
    const LINE_GAP = 2;

    function draw(dc as Graphics.Dc, stop as NearbyStop?, status as String,
                  statute as Boolean) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, dc.getWidth(), HEADER_HEIGHT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, HEADER_HEIGHT / 2, Graphics.FONT_TINY,
                    WatchUi.loadResource(Rez.Strings.GlanceTitle) as String,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        if (stop != null) {
            drawName(dc, stop.name);
            dc.drawText(dc.getWidth() / 2, DETAIL_Y, Graphics.FONT_MEDIUM,
                        StopFinder.detail(stop, statute), Graphics.TEXT_JUSTIFY_CENTER);
            drawSubscreenArrow(dc, stop.bearing);
        }
        dc.drawText(dc.getWidth() / 2, STATUS_Y, Graphics.FONT_XTINY, status,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // The name sits on the baseline above the distance, growing upward so
    // one long name pushes into the space a short one leaves empty.
    function drawName(dc as Graphics.Dc, name as String) as Void {
        var fonts = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>;
        var font = TextFit.fontFor(dc, name, fonts, CONTENT_WIDTH);
        var lines = TextFit.wrap(dc, name, font, CONTENT_WIDTH);
        var lineHeight = dc.getFontHeight(font);
        var y = NAME_BOTTOM - (lines.size() * lineHeight) - ((lines.size() - 1) * LINE_GAP);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(dc.getWidth() / 2, y, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineHeight + LINE_GAP;
        }
    }

    // Instinct's round subscreen carries a north-up arrow toward the stop.
    function drawSubscreenArrow(dc as Graphics.Dc, bearing as Number) as Void {
        var subscreen = WatchUi.getSubscreen();
        if (subscreen == null || subscreen.x == null || subscreen.y == null) { return; }
        var centerX = (subscreen.x as Number) + (subscreen.width / 2);
        var centerY = (subscreen.y as Number) + (subscreen.height / 2);
        var radius = (subscreen.width / 2).toNumber();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, radius);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.fillPolygon(arrow(centerX, centerY, radius - 6, bearing));
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
    }

    // Tip, then the two barbs, then the notch at the tail.
    function arrow(centerX as Number, centerY as Number, reach as Number,
                   bearing as Number) as Array<[Numeric, Numeric]> {
        var shape = [[0, -reach], [reach / 2, reach], [0, reach / 2], [-reach / 2, reach]]
                    as Array<[Numeric, Numeric]>;
        var radians = Math.toRadians(bearing);
        var sine = Math.sin(radians);
        var cosine = Math.cos(radians);
        var points = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < shape.size(); i++) {
            var x = shape[i][0];
            var y = shape[i][1];
            points.add([centerX + ((x * cosine) - (y * sine)).toNumber(),
                        centerY + ((x * sine) + (y * cosine)).toNumber()]);
        }
        return points;
    }
}

// The app screen: the closest stop, larger, with a live GPS fix behind it.
class MuniView extends WatchUi.View {
    private var _stop as NearbyStop?;
    private var _live as Boolean = false;
    private var _searching as Boolean = false;

    function initialize() {
        View.initialize();
        _stop = null;
    }

    function onShow() as Void {
        refresh(Locator.current());
        _searching = true;
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function onHide() as Void {
        _searching = false;
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    function onPosition(info as Position.Info) as Void {
        var fix = Locator.fromSystem();
        if (fix == null) { return; }
        Locator.remember(fix);
        _searching = false;
        refresh(fix);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        MuniRenderer.draw(dc, _stop, status(), Units.statute());
    }

    // The stops behind the one on screen, for the nearby list.
    function stops() as Array<NearbyStop> {
        var fix = Locator.current();
        if (fix == null) { return [] as Array<NearbyStop>; }
        return StopFinder.nearestStops(fix.latitude, fix.longitude, 8);
    }

    private function refresh(fix as Fix?) as Void {
        if (fix == null) {
            _stop = null;
            _live = false;
            return;
        }
        _stop = StopFinder.nearest(fix.latitude, fix.longitude);
        _live = fix.live;
    }

    private function status() as String {
        if (_stop == null) {
            return WatchUi.loadResource(
                _searching ? Rez.Strings.Searching : Rez.Strings.NoStop) as String;
        }
        if (_live) { return WatchUi.loadResource(Rez.Strings.LiveFix) as String; }
        return WatchUi.loadResource(Rez.Strings.StoredFix) as String;
    }
}

class MuniDelegate extends WatchUi.BehaviorDelegate {
    private var _view as MuniView;

    function initialize(view as MuniView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        var stops = _view.stops();
        if (stops.size() == 0) { return false; }
        var menu = new NearbyMenu(stops, Units.statute());
        WatchUi.pushView(menu, new NearbyMenuDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }
}
