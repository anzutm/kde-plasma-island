// ConfigGeneral.qml — Clock & Weather settings
// Fix: weatherTempUnit is String in schema ("C"/"F"), not Int
//      cfg_ properties must be declared as correct type, not alias to wrong type
import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // ── cfg_ bindings (names MUST match schema entry names exactly) ──
    property alias cfg_clockUse24h:            use24hSwitch.checked
    property alias cfg_clockShowSeconds:       showSecondsSwitch.checked
    property alias cfg_showWeatherWidget:      weatherSwitch.checked
    property alias cfg_weatherLocation:        locationField.text
    property alias cfg_weatherRefreshInterval: weatherIntervalSpin.value

    // weatherTempUnit is String ("C" / "F") — cannot alias to ComboBox.currentIndex
    // Use explicit string property instead
    property string cfg_weatherTempUnit: "C"

    onCfg_weatherTempUnitChanged: {
        tempUnitCombo.currentIndex = (cfg_weatherTempUnit === "F" ? 1 : 0)
    }

    Kirigami.FormLayout {
        // ── Clock ─────────────────────────────────────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("🕐  Clock")
        }

        QC.Switch {
            id: use24hSwitch
            Kirigami.FormData.label: i18n("24-hour format")
        }

        QC.Switch {
            id: showSecondsSwitch
            Kirigami.FormData.label: i18n("Show seconds")
        }

        // ── Weather ───────────────────────────────────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("☁️  Weather")
        }

        QC.Switch {
            id: weatherSwitch
            Kirigami.FormData.label: i18n("Show weather widget")
        }

        QC.TextField {
            id: locationField
            placeholderText: i18n("Leave empty for auto-detect (by IP)")
            Kirigami.FormData.label: i18n("Location")
            Layout.preferredWidth: 240
            enabled: weatherSwitch.checked
        }

        // Temperature unit: ComboBox synced to String schema key
        QC.ComboBox {
            id: tempUnitCombo
            Kirigami.FormData.label: i18n("Temperature unit")
            enabled: weatherSwitch.checked
            model: [i18n("Celsius (°C)"), i18n("Fahrenheit (°F)")]
            Component.onCompleted: {
                currentIndex = page.cfg_weatherTempUnit === "F" ? 1 : 0
            }
            onActivated: {
                page.cfg_weatherTempUnit = currentIndex === 1 ? "F" : "C"
            }
        }

        QC.SpinBox {
            id: weatherIntervalSpin
            from: 1; to: 120; stepSize: 5
            editable: true
            Kirigami.FormData.label: i18n("Refresh interval (minutes)")
            enabled: weatherSwitch.checked
            textFromValue: function(value) { return i18n("%1 min", value) }
        }
    }
}
