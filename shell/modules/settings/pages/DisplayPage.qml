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
    }
}
