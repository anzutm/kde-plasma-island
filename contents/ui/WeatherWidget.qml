// WeatherWidget.qml — Plasma Island for KDE Plasma 6
// Clean Kirigami symbolic icons with fallback, temperature unit formatting
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: root

    readonly property bool   showWidget:     plasmoid.configuration.showWeatherWidget
    readonly property string tempUnit:       plasmoid.configuration.weatherTempUnit
    readonly property int    refreshMinutes: plasmoid.configuration.weatherRefreshInterval
    readonly property string location:       plasmoid.configuration.weatherLocation
    readonly property bool   isAutoLocation: location.trim() === ""
    readonly property bool   isLight:        plasmoid.configuration.themeMode === "light"

    onTempUnitChanged:       if (showWidget) fetchWeather()
    onLocationChanged:       if (showWidget) locationDebounce.restart()
    onRefreshMinutesChanged: refreshTimer.restart()

    visible:        showWidget
    implicitWidth:  showWidget ? row.implicitWidth + 18 : 0
    implicitHeight: 34

    property string temp:         "--"
    property string weatherCode:  "113"
    property bool   loading:      true
    property bool   hasError:     false
    property var    _activeXhr:   null

    function codeToIcon(code) {
        const c = parseInt(code)
        if (c === 113)                                  return "weather-clear-symbolic"
        if (c === 116)                                  return "weather-few-clouds-symbolic"
        if ([119, 122].includes(c))                     return "weather-overcast-symbolic"
        if ([143, 248, 260].includes(c))                return "weather-fog-symbolic"
        if ([176, 263, 266, 293, 296, 353].includes(c)) return "weather-showers-scattered-symbolic"
        if ([299, 302, 305, 308, 356, 359].includes(c)) return "weather-showers-symbolic"
        if ([200, 386, 389, 392, 395].includes(c))      return "weather-storm-symbolic"
        if (c >= 179 && c <= 395)                       return "weather-snow-symbolic"
        return "weather-clouds-symbolic"
    }

    function fetchWeather() {
        if (root._activeXhr) {
            root._activeXhr.abort()
            root._activeXhr = null
        }

        root.loading  = true
        root.hasError = false
        const loc  = root.location.trim()
        const unit = root.tempUnit === "F" ? "u" : "m"
        // encodeURIComponent sanitizes location for HTTP query; empty loc uses wttr.in IP geolocation
        const url  = `https://wttr.in/${encodeURIComponent(loc)}?format=j1&${unit}`

        const xhr = new XMLHttpRequest()
        root._activeXhr = xhr
        xhr.timeout = 10000
        xhr.ontimeout = function() {
            if (root._activeXhr !== xhr) return
            root._activeXhr = null
            root.loading = false
            root.hasError = true
        }
        xhr.onerror = function() {
            if (root._activeXhr !== xhr) return
            root._activeXhr = null
            root.loading = false
            root.hasError = true
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || root._activeXhr !== xhr) return
            root._activeXhr = null
            if (xhr.status === 200) {
                try {
                    const data = JSON.parse(xhr.responseText)
                    const cc   = data.current_condition[0]
                    const t    = root.tempUnit === "F" ? cc.temp_F : cc.temp_C
                    root.temp        = t + "°" + root.tempUnit
                    root.weatherCode = cc.weatherCode
                    root.hasError    = false
                } catch(e) {
                    root.hasError = true
                }
            } else {
                root.hasError = true
            }
            root.loading = false
        }
        xhr.open("GET", url)
        xhr.send()
    }

    Timer {
        id: locationDebounce
        interval: 400
        repeat:   false
        onTriggered: root.fetchWeather()
    }

    Timer {
        id: refreshTimer
        interval:         Math.max(1, parseInt(root.refreshMinutes) || 10) * 60000
        running:          root.showWidget
        repeat:           true
        triggeredOnStart: true
        onTriggered:      root.fetchWeather()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Kirigami.Icon {
            source:           root.codeToIcon(root.weatherCode)
            implicitWidth:    15
            implicitHeight:   15
            anchors.verticalCenter: parent.verticalCenter
            isMask:           true
            color:            root.isLight ? "#18181b" : "white"
            visible:          !(root.loading && root.temp === "--")
        }

        PC3.Label {
            text:             (root.loading && root.temp === "--") ? "⏳" : (root.hasError && root.temp === "--" ? i18n("N/A") : root.temp)
            font.pixelSize:   12
            font.weight:      Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
            color:            (root.hasError && root.temp === "--")
                              ? (root.isLight ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.4))
                              : (root.isLight ? "#18181b" : "white")
        }
    }

    MouseArea {
        id: weatherMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.fetchWeather()
    }

    readonly property string locationLabel: root.isAutoLocation
                                          ? i18n("Auto-detected via IP")
                                          : root.location.trim()

    PC3.ToolTip.text:    root.loading
                         ? i18n("Fetching weather (%1)...", root.locationLabel)
                         : (root.hasError
                            ? i18n("Last: %1 (%2 — Refresh failed, click to retry)", root.temp, root.locationLabel)
                            : i18n("Current: %1 (%2 — Click to refresh)", root.temp, root.locationLabel))
    PC3.ToolTip.visible: weatherMouseArea.containsMouse
    PC3.ToolTip.delay:   600
}
