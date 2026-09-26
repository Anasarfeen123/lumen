pragma Singleton
// Sunrise and sunset for today, computed locally (NOAA sunrise equation) from
// the place you set for weather. No place → 06:30 / 18:30. No network.
//   phase: "dawn" (sunrise ±1 h) · "day" · "dusk" (sunset ±1 h) · "night"
import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var place: Persist.data.weatherPlace ?? null
    property date now: new Date()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.now = new Date() }

    readonly property var times: compute(now, place)
    readonly property date sunrise: times.sunrise
    readonly property date sunset: times.sunset
    readonly property bool known: place !== null
    readonly property string phase: {
        const t = now.getTime(), r = sunrise.getTime(), s = sunset.getTime(), h = 3600000;
        if (t >= r - h && t < r + h) return "dawn";
        if (t >= r + h && t < s - h) return "day";
        if (t >= s - h && t < s + h) return "dusk";
        return "night";
    }

    function compute(date, p) {
        const at = (hh, mm) => { const d = new Date(date); d.setHours(hh, mm, 0, 0); return d; };
        if (!p) return { sunrise: at(6, 30), sunset: at(18, 30) };
        const rise = event(date, p.lat, p.lon, true), set = event(date, p.lat, p.lon, false);
        return { sunrise: rise ?? at(6, 30), sunset: set ?? at(18, 30) };
    }

    // NOAA "sunrise equation" (zenith 90.833°: official sunrise/sunset)
    function event(date, lat, lon, rising) {
        const rad = Math.PI / 180, deg = 180 / Math.PI;
        const start = new Date(date.getFullYear(), 0, 0);
        const N = Math.floor((new Date(date.getFullYear(), date.getMonth(), date.getDate()) - start) / 86400000);
        const lngHour = lon / 15;
        const t = N + ((rising ? 6 : 18) - lngHour) / 24;
        const M = 0.9856 * t - 3.289;
        let L = M + 1.916 * Math.sin(M * rad) + 0.020 * Math.sin(2 * M * rad) + 282.634;
        L = ((L % 360) + 360) % 360;
        let RA = deg * Math.atan(0.91764 * Math.tan(L * rad));
        RA = ((RA % 360) + 360) % 360;
        RA += Math.floor(L / 90) * 90 - Math.floor(RA / 90) * 90;
        RA /= 15;
        const sinDec = 0.39782 * Math.sin(L * rad);
        const cosDec = Math.cos(Math.asin(sinDec));
        const cosH = (Math.cos(90.833 * rad) - sinDec * Math.sin(lat * rad)) / (cosDec * Math.cos(lat * rad));
        if (cosH > 1 || cosH < -1) return null;               // polar day / night
        let H = rising ? 360 - deg * Math.acos(cosH) : deg * Math.acos(cosH);
        H /= 15;
        const T = H + RA - 0.06571 * t - 6.622;
        let UT = T - lngHour;
        UT = ((UT % 24) + 24) % 24;
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) + UT * 3600000);
        // UT can land on the neighbouring UTC day for far east/west longitudes
        if (d.getDate() !== date.getDate()) d.setDate(date.getDate());
        return d;
    }
}
