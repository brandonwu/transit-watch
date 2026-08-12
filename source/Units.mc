import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.System;

// Distance units, from the app setting when it overrides the watch.
(:glance)
module Units {
    const AUTOMATIC = 0;
    const MILES = 1;
    const KILOMETERS = 2;

    function statute() as Boolean {
        var setting = Properties.getValue("units");
        if (setting instanceof Number) {
            if (setting == MILES) { return true; }
            if (setting == KILOMETERS) { return false; }
        }
        return System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE;
    }
}
