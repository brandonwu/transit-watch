import Toybox.Graphics;
import Toybox.Lang;

// Fitting a stop name into a narrow strip.
//
// "Embarcadero & Washington - 0.3mi N" is wider than any Instinct screen,
// so the caller offers a ladder of fonts and, if even the smallest is too
// wide, the name is clipped while the distance stays intact.
(:glance)
module TextFit {
    function fontFor(dc as Graphics.Dc, text as String, fonts as Array<Graphics.FontType>,
                     maxWidth as Number) as Graphics.FontType {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth) { return fonts[i]; }
        }
        return fonts[fonts.size() - 1];
    }

    // `head` shortened just enough that head + tail fits, with ".." marking
    // what was dropped.
    function clip(dc as Graphics.Dc, head as String, tail as String,
                  font as Graphics.FontType, maxWidth as Number) as String {
        if (dc.getTextWidthInPixels(head + tail, font) <= maxWidth) { return head + tail; }
        var length = head.length();
        while (length > 0) {
            var candidate = head.substring(0, length) + ".." + tail;
            if (dc.getTextWidthInPixels(candidate, font) <= maxWidth) { return candidate; }
            length--;
        }
        return ".." + tail;
    }

    // Splits a stop name onto at most two lines at the last space that
    // fits, so "Embarcadero & Washington" breaks after the ampersand.
    function wrap(dc as Graphics.Dc, text as String, font as Graphics.FontType,
                  maxWidth as Number) as Array<String> {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) { return [text]; }
        var characters = text.toCharArray();
        var best = -1;
        for (var i = 1; i < characters.size(); i++) {
            if (characters[i].toNumber() != 32) { continue; }
            var head = text.substring(0, i) as String;
            if (dc.getTextWidthInPixels(head, font) > maxWidth) { break; }
            best = i;
        }
        if (best < 0) { return [clip(dc, text, "", font, maxWidth)]; }
        var tail = text.substring(best + 1, text.length()) as String;
        return [text.substring(0, best) as String, clip(dc, tail, "", font, maxWidth)];
    }
}
