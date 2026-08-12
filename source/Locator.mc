import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Position;
import Toybox.System;

// Where the rider is, and how much to trust it.
(:glance)
class Fix {
    var latitude as Double;
    var longitude as Double;
    var live as Boolean; // False when this came from the stored fallback.

    function initialize(lat as Double, lon as Double, isLive as Boolean) {
        latitude = lat;
        longitude = lon;
        live = isLive;
    }
}

// Position lookup shared by the glance and the app.
//
// A glance cannot turn the GPS on, so it reads whatever fix the system
// already has and falls back to the last one this app recorded. The app
// view runs the GPS and writes that fallback back to storage.
(:glance)
module Locator {
    const STORED_LATITUDE = "fixLatitude";
    const STORED_LONGITUDE = "fixLongitude";

    function current() as Fix? {
        var live = fromSystem();
        if (live != null) { return live; }
        return stored();
    }

    function fromSystem() as Fix? {
        var info = Position.getInfo();
        if (info == null || info.position == null) { return null; }
        if (info.accuracy == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
            return null;
        }
        var degrees = (info.position as Position.Location).toDegrees();
        if (!isPlausible(degrees[0], degrees[1])) { return null; }
        return new Fix(degrees[0], degrees[1], true);
    }

    function stored() as Fix? {
        var latitude = Storage.getValue(STORED_LATITUDE);
        var longitude = Storage.getValue(STORED_LONGITUDE);
        if (!(latitude instanceof Double) || !(longitude instanceof Double)) {
            return null;
        }
        if (!isPlausible(latitude, longitude)) { return null; }
        return new Fix(latitude, longitude, false);
    }

    function remember(fix as Fix) as Void {
        Storage.setValue(STORED_LATITUDE, fix.latitude);
        Storage.setValue(STORED_LONGITUDE, fix.longitude);
    }

    // A watch with no fix reports 0,0 or 180,180 depending on the model.
    function isPlausible(latitude as Double, longitude as Double) as Boolean {
        if (latitude > 90.0 || latitude < -90.0) { return false; }
        if (longitude > 180.0 || longitude < -180.0) { return false; }
        return !(latitude == 0.0 && longitude == 0.0);
    }
}
