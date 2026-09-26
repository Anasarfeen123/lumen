pragma Singleton
// Weather from Open-Meteo (open-meteo.com: free, no key, no account).
// Nothing is fetched until you set a place (left sidebar or Settings); then
// every 30 minutes while the shell runs. Only the coordinates you chose are
// sent — no IP geolocation.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var place: Persist.data.weatherPlace ?? null    // { name, lat, lon }
    property var now: null          // { temp, code, wind, feels, isDay }
    property var days: []           // [{ date, max, min, code }]
    property bool loading: false
    property string error: ""
    readonly property bool ready: now !== null

    function setPlace(query) {
        if (!query.trim()) return;
        error = "";
        geo.command = ["curl", "-fsS", "--max-time", "8",
                       "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(query.trim())];
        geo.running = true;
    }
    function clearPlace() { Persist.data.weatherPlace = null; now = null; days = []; }
    function refresh() {
        if (!place) return;
        loading = true;
        fetch.command = ["curl", "-fsS", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + Number(place.lat).toFixed(3) + "&longitude=" + Number(place.lon).toFixed(3)
            + "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=5&timezone=auto"];
        fetch.running = true;
    }
    onPlaceChanged: refresh()
    Timer { interval: 30 * 60 * 1000; running: root.place !== null; repeat: true; onTriggered: root.refresh() }

    Process {
        id: geo
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text).results?.[0];
                    if (!r) { root.error = "Couldn't find that place"; return; }
                    Persist.data.weatherPlace = { name: r.name + (r.country_code ? ", " + r.country_code : ""), lat: r.latitude, lon: r.longitude };
                } catch (e) { root.error = "Couldn't reach the weather service"; }
            }
        }
    }
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const d = JSON.parse(text);
                    const c = d.current;
                    root.now = { temp: c.temperature_2m, feels: c.apparent_temperature, code: c.weather_code, wind: c.wind_speed_10m, isDay: c.is_day === 1 };
                    root.days = d.daily.time.map((t, i) => ({ date: t, max: d.daily.temperature_2m_max[i], min: d.daily.temperature_2m_min[i], code: d.daily.weather_code[i] }));
                    root.error = "";
                } catch (e) { root.error = "Couldn't reach the weather service"; }
            }
        }
        onExited: code => { if (code !== 0) { root.loading = false; root.error = "Couldn't reach the weather service"; } }
    }

    // WMO weather codes → words and Material Symbols
    function describe(code) {
        if (code === 0) return "Clear";
        if (code <= 2) return "Partly cloudy";
        if (code === 3) return "Overcast";
        if (code <= 48) return "Fog";
        if (code <= 57) return "Drizzle";
        if (code <= 67) return "Rain";
        if (code <= 77) return "Snow";
        if (code <= 82) return "Showers";
        if (code <= 86) return "Snow showers";
        return "Thunderstorm";
    }
    function icon(code, isDay) {
        if (code === 0) return isDay === false ? "clear_night" : "sunny";
        if (code <= 2) return isDay === false ? "nights_stay" : "partly_cloudy_day";
        if (code === 3) return "cloud";
        if (code <= 48) return "foggy";
        if (code <= 67) return "rainy";
        if (code <= 77) return "weather_snowy";
        if (code <= 82) return "rainy";
        if (code <= 86) return "weather_snowy";
        return "thunderstorm";
    }
}
