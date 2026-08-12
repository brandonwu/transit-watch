import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MuniApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new MuniView();
        return [view, new MuniDelegate(view)];
    }

    (:glance)
    function getGlanceView() {
        return [new MuniGlanceView()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

function getApp() {
    return Application.getApp();
}
