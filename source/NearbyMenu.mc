import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class NearbyMenuTitle extends WatchUi.Drawable {
    function initialize() {
        Drawable.initialize({});
    }

    function draw(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(25, dc.getHeight() / 2, Graphics.FONT_MEDIUM,
                    WatchUi.loadResource(Rez.Strings.NearbyTitle) as String,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// The stops behind the closest one, in case the rider wants the other
// direction or the next station up the line.
class NearbyMenu extends WatchUi.Menu2 {
    function initialize(stops as Array<NearbyStop>, statute as Boolean) {
        Menu2.initialize({ :title => new NearbyMenuTitle() });
        for (var i = 0; i < stops.size(); i++) {
            addItem(new WatchUi.MenuItem(stops[i].name,
                                         StopFinder.detail(stops[i], statute), i, {
                :alignment => WatchUi.MenuItem.MENU_ITEM_LABEL_ALIGN_LEFT
            }));
        }
    }
}

class NearbyMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
