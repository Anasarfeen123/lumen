// Display: brightness, night light.
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Display"

    Group {
        title: "Brightness"
        SetRow {
            icon: "brightness_6"
            title: "Screen brightness"
            LSlider { width: 260; icon: "light_mode"; value: Brightness.value; onMoved: v => Brightness.set(v) }
        }
    }

    Group {
        title: "Night light"
        SetRow {
            icon: "nightlight"
            title: "Night light"
            description: "Warmer colours to ease your eyes in the evening"
            // Writes the preference; the main shell's NightLight service runs hyprsunset
            LSwitch { checked: Persist.data.nightLight; onToggled: Persist.data.nightLight = !checked }
        }
        SetRow {
            icon: "thermostat"
            title: "Warmth"
            description: Persist.data.nightLightTemp + " K"
            LSlider {
                width: 260
                icon: "wb_sunny"
                // 6500 K (neutral) → 2500 K (very warm), left to right
                value: (6500 - Persist.data.nightLightTemp) / 4000
                onMoved: v => Persist.data.nightLightTemp = Math.round((6500 - v * 4000) / 100) * 100
            }
        }
        SetRow {
            icon: "wb_twilight"
            title: "Automatically"
            description: Persist.data.nightLightAuto === "sun"
                ? "On at sunset (" + Qt.formatTime(Sun.sunset, Theme.timeFormatFull) + "), off at sunrise (" + Qt.formatTime(Sun.sunrise, Theme.timeFormatFull) + ")"
                  + (Sun.known ? "" : " — set your city in the left sidebar for exact times")
                : Persist.data.nightLightAuto === "custom" ? "On and off at the hours you choose" : "Only when you switch it"
            Segmented {
                width: 340
                options: [{ id: "off", label: "Off" }, { id: "sun", label: "Sunset → sunrise" }, { id: "custom", label: "Custom" }]
                current: Persist.data.nightLightAuto ?? "off"
                onPicked: id => Persist.data.nightLightAuto = id
            }
        }
        SetRow {
            visible: Persist.data.nightLightAuto === "custom"
            icon: "schedule"
            title: "Hours"
            Row {
                spacing: Theme.space.s2
                LField { width: 78; clearOnAccept: false; text: Persist.data.nightLightFrom
                         onAccepted: t => { if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(t.trim())) Persist.data.nightLightFrom = t.trim(); else text = Persist.data.nightLightFrom; } }
                LText { text: "to"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                LField { width: 78; clearOnAccept: false; text: Persist.data.nightLightTo
                         onAccepted: t => { if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(t.trim())) Persist.data.nightLightTo = t.trim(); else text = Persist.data.nightLightTo; } }
            }
        }
    }
}
