import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The glance: a title line and the closest Muni Metro stop.
//
//     MUNI METRO
//     Embarcadero - 0.3mi N
//
// Instinct 2X redraws glances in the background rather than live, so this
// view does its whole job inside one onUpdate() with whatever position the
// system already has. It never turns the GPS on.
(:glance)
class MuniGlanceView extends WatchUi.GlanceView {
    private const LINE_GAP = 2;

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var titleFont = Graphics.FONT_XTINY;
        var titleHeight = dc.getFontHeight(titleFont);
        var detailFont = Graphics.FONT_TINY;
        var detailHeight = dc.getFontHeight(detailFont);
        var top = ((dc.getHeight() - titleHeight - detailHeight - LINE_GAP) / 2).toNumber();
        if (top < 0) { top = 0; }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, top, titleFont, WatchUi.loadResource(Rez.Strings.GlanceTitle) as String,
                    Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(0, top + titleHeight + LINE_GAP, detailFont,
                    summary(dc, detailFont, dc.getWidth()), Graphics.TEXT_JUSTIFY_LEFT);
    }

    // "Embarcadero - 0.3mi N", clipped to the width on offer, or why not.
    private function summary(dc as Graphics.Dc, font as Graphics.FontType,
                             maxWidth as Number) as String {
        var fix = Locator.current();
        if (fix == null) { return WatchUi.loadResource(Rez.Strings.NoFix) as String; }

        var stop = StopFinder.nearest(fix.latitude, fix.longitude);
        if (stop == null) { return WatchUi.loadResource(Rez.Strings.NoStop) as String; }

        return TextFit.clip(dc, stop.name, " - " + StopFinder.detail(stop, Units.statute()),
                            font, maxWidth);
    }
}
