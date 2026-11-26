// ClockWidget.qml — Plasma Island for KDE Plasma 6
// Anti-Jitter: Uses OpenType Tabular Numbers (tnum) + TextMetrics-measured fixed width
import QtQuick
import org.kde.plasma.components as PC3

Item {
    id: root

    readonly property bool use24h:      plasmoid.configuration.clockUse24h
    readonly property bool showSeconds: plasmoid.configuration.clockShowSeconds
    readonly property bool isLight:     plasmoid.configuration.themeMode === "light"
    property real uiScale: 1.0

    TextMetrics {
        id: timeMetrics
        font: timeLabel.font
        text: root.showSeconds ? (root.use24h ? "88:88:88" : "88:88:88 PM") : (root.use24h ? "88:88" : "88:88 PM")
    }

    // Dynamic safe width based on widest tabular string and date text prevents both jitter and clipping
    implicitWidth:  Math.ceil(Math.max(timeMetrics.advanceWidth, dateLabel.contentWidth) + Math.round(4 * uiScale))
    implicitHeight: Math.max(col.implicitHeight, Math.round(34 * uiScale))

    property string _lastTime: ""
    property string _lastDateKey: ""

    function formatTime(now) {
        let h     = now.getHours()
        const m   = String(now.getMinutes()).padStart(2, '0')
        const s   = String(now.getSeconds()).padStart(2, '0')
        let sfx   = ''
        if (!use24h) {
            sfx = h >= 12 ? ' PM' : ' AM'
            h   = h % 12 || 12
        }
        const hs = String(h).padStart(2, '0')
        return showSeconds ? `${hs}:${m}:${s}${sfx}` : `${hs}:${m}${sfx}`
    }

    function formatDate(now) {
        // Locale-aware short date (e.g. "Wed, 25 Nov")
        return Qt.formatDate(now, "ddd, d MMM")
    }

    Timer {
        id: clockTimer
        // 500 ms interval when showing seconds avoids skipping a second due to timer jitter
        interval:         root.showSeconds ? 500 : 1000
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            const tStr = root.formatTime(now)
            if (tStr !== root._lastTime) {
                root._lastTime = tStr
                timeLabel.text = tStr
            }
            const dKey = `${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`
            if (dKey !== root._lastDateKey) {
                root._lastDateKey = dKey
                dateLabel.text = root.formatDate(now)
            }
        }
    }

    Column {
        id: col
        anchors.centerIn: parent
        width: parent.width
        spacing: 0

        PC3.Label {
            id:                  timeLabel
            width:               parent.width
            text:                root.formatTime(new Date())
            font.pixelSize:      Math.round(14 * root.uiScale)
            font.weight:         Font.Bold
            // OpenType Tabular Numbers: all digits 0-9 share exact same width
            font.features:       { "tnum": 1 }
            horizontalAlignment: Text.AlignHCenter
            color:               root.isLight ? "#18181b" : "white"
        }

        PC3.Label {
            id:                  dateLabel
            width:               parent.width
            text:                root.formatDate(new Date())
            font.pixelSize:      Math.round(10 * root.uiScale)
            font.weight:         Font.Normal
            horizontalAlignment: Text.AlignHCenter
            color:               root.isLight ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.45)
            font.letterSpacing:  0.2 * root.uiScale
        }
    }
}
