// ConfigModules.qml — Module toggle & refresh settings
// Fix: all cfg_ aliases match schema entry names exactly (camelCase)
//      disabled sub-switches when parent is off
//      refresh interval SpinBox shows correct unit label
import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // Widget order, 3-zone mode & assignment
    property alias  cfg_pillFullWidth: fullWidthSwitch.checked
    property string cfg_widgetOrder:   "clock,weather,workspace,media,status"
    property string cfg_widgetZones:   "clock:left,weather:left,workspace:left,media:center,status:right"
    property bool   _syncingOrder:     false
    property bool   unsavedChanges:    liveSync.unsavedChanges

    function saveConfig() {
        liveSync.commitSaved()
    }

    LiveConfigSync {
        id: liveSync
        targetPage: page
        keys: [
            "pillFullWidth", "widgetOrder", "widgetZones",
            "showWorkspaceWidget", "workspaceHideEmpty",
            "showMediaWidget", "mediaAutoHide",
            "showStatusWidget",
            "statusShowNetwork", "statusShowBluetooth",
            "statusShowBattery", "statusShowVolume",
            "statusShowNetSpeed", "statusShowCpu",
            "statusShowTemp", "statusShowRam",
            "statusShowActions", "statusRefreshInterval"
        ]
    }

    // Workspace
    property alias cfg_showWorkspaceWidget: workspaceSwitch.checked
    property alias cfg_workspaceHideEmpty:  hideEmptySwitch.checked

    // Media
    property alias cfg_showMediaWidget: mediaSwitch.checked
    property alias cfg_mediaAutoHide:   autoHideSwitch.checked

    // Status widget master toggle
    property alias cfg_showStatusWidget: statusSwitch.checked

    // Status sub-items
    property alias cfg_statusShowNetwork:   netSwitch.checked
    property alias cfg_statusShowBluetooth: btSwitch.checked
    property alias cfg_statusShowBattery:   batSwitch.checked
    property alias cfg_statusShowVolume:    volSwitch.checked
    property alias cfg_statusShowNetSpeed:  netSpeedSwitch.checked
    property alias cfg_statusShowCpu:       cpuSwitch.checked
    property alias cfg_statusShowTemp:      tempSwitch.checked
    property alias cfg_statusShowRam:       ramSwitch.checked
    property alias cfg_statusShowActions:   actionsSwitch.checked
    property alias cfg_statusRefreshInterval: refreshSpin.value

    readonly property var widgetCatalog: ({
        "clock":     { label: i18n("Clock"),         shortLabel: i18n("Clock"),  icon: "clock" },
        "weather":   { label: i18n("Weather"),       shortLabel: i18n("Weather"), icon: "weather-few-clouds-symbolic" },
        "workspace": { label: i18n("Workspaces"),    shortLabel: i18n("Spaces"), icon: "view-grid-symbolic" },
        "media":     { label: i18n("Media Player"),  shortLabel: i18n("Media"),  icon: "media-playback-start-symbolic" },
        "status":    { label: i18n("System Status"), shortLabel: i18n("Status"), icon: "preferences-system-symbolic" }
    })
    readonly property var    defaultOrder: ["clock", "weather", "workspace", "media", "status"]
    readonly property string defaultZonesStr: "clock:left,weather:left,workspace:left,media:center,status:right"
    readonly property var    defaultZoneMap: ({ "clock": "left", "weather": "left", "workspace": "left", "media": "center", "status": "right" })

    property var orderKeys: ["clock", "weather", "workspace", "media", "status"]
    property var zoneMap:   ({ "clock": "left", "weather": "left", "workspace": "left", "media": "center", "status": "right" })

    function normalizeOrder(raw) {
        const parts = (raw || "").split(",").map(s => s.trim()).filter(s => s !== "")
        const seen = {}
        const result = []
        for (let i = 0; i < parts.length; i++) {
            const k = parts[i]
            if (widgetCatalog[k] && !seen[k]) {
                seen[k] = true
                result.push(k)
            }
        }
        for (let i = 0; i < defaultOrder.length; i++) {
            const k = defaultOrder[i]
            if (!seen[k]) {
                seen[k] = true
                result.push(k)
            }
        }
        return result
    }

    function normalizeZones(raw) {
        const map = { "clock": defaultZoneMap["clock"], "weather": defaultZoneMap["weather"],
                      "workspace": defaultZoneMap["workspace"], "media": defaultZoneMap["media"],
                      "status": defaultZoneMap["status"] }
        const validZ = { "left": true, "center": true, "right": true }
        const parts = (raw || "").split(",")
        for (let i = 0; i < parts.length; i++) {
            const pair = parts[i].split(":")
            if (pair.length === 2) {
                const k = pair[0].trim()
                const z = pair[1].trim()
                if (map[k] !== undefined && validZ[z]) map[k] = z
            }
        }
        return map
    }

    function serializeZones(map) {
        return defaultOrder.map(k => k + ":" + (map[k] || defaultZoneMap[k])).join(",")
    }

    function sortOrderByZone(keys, map) {
        const buckets = { "left": [], "center": [], "right": [] }
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            const z = map[k] || "left"
            buckets[z].push(k)
        }
        return buckets["left"].concat(buckets["center"], buckets["right"])
    }

    function loadOrderFromConfig() {
        if (_syncingOrder) return
        const keys = normalizeOrder(cfg_widgetOrder)
        const map  = normalizeZones(cfg_widgetZones)
        const sameOrder = (orderKeys.join(",") === keys.join(","))
        const sameZones = (serializeZones(zoneMap) === serializeZones(map))
        if (sameOrder && sameZones) return
        _syncingOrder = true
        if (!sameOrder) orderKeys = keys
        if (!sameZones) zoneMap = map
        _syncingOrder = false
    }

    function commitOrderAndZones(nextKeys, nextMap) {
        _syncingOrder = true
        orderKeys = nextKeys
        zoneMap   = nextMap
        cfg_widgetOrder = nextKeys.join(",")
        cfg_widgetZones = serializeZones(nextMap)
        _syncingOrder = false
    }

    function setWidgetZone(widgetKey, targetZone) {
        if (!widgetCatalog[widgetKey] || !["left", "center", "right"].includes(targetZone)) return
        if (zoneMap[widgetKey] === targetZone) return
        const nextMap = Object.assign({}, zoneMap)
        nextMap[widgetKey] = targetZone
        const nextKeys = sortOrderByZone(orderKeys, nextMap)
        commitOrderAndZones(nextKeys, nextMap)
    }

    function moveOrderItem(fromIdx, toIdx) {
        if (fromIdx < 0 || toIdx < 0 || fromIdx >= orderKeys.length || toIdx >= orderKeys.length || fromIdx === toIdx) {
            return
        }
        const targetZone = zoneMap[orderKeys[toIdx]] || "left"
        const next = orderKeys.slice()
        const moved = next.splice(fromIdx, 1)[0]
        next.splice(toIdx, 0, moved)
        const nextMap = Object.assign({}, zoneMap)
        // Adopting target slot's zone keeps Left → Center → Right grouping consistent when dragging across zones
        nextMap[moved] = targetZone
        commitOrderAndZones(next, nextMap)
    }

    function zoneSummary(zoneName) {
        const names = []
        for (let i = 0; i < orderKeys.length; i++) {
            const k = orderKeys[i]
            if ((zoneMap[k] || "left") === zoneName) {
                names.push(widgetCatalog[k].shortLabel)
            }
        }
        return names.length > 0 ? names.join(" · ") : i18n("Empty")
    }

    onCfg_widgetOrderChanged: loadOrderFromConfig()
    onCfg_widgetZonesChanged: loadOrderFromConfig()
    Component.onCompleted:    loadOrderFromConfig()

    Kirigami.FormLayout {

        // ── Widget Order & 3-Zone Placement ───────────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("🔀  Widget Order & 3-Zone Layout")
        }

        QC.Switch {
            id: fullWidthSwitch
            Kirigami.FormData.label: i18n("Full-width bar (3-zone layout)")
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Layout")
            spacing: 8

            // Live 3-Zone Visual Indicator Bar
            RowLayout {
                id: zonePreviewBar
                readonly property bool isFullWidthBar: fullWidthSwitch.checked
                Layout.preferredWidth: 356
                spacing: 4

                Repeater {
                    model: [
                        { id: "left",   title: i18n("Left Zone"),   accent: "#3b82f6" },
                        { id: "center", title: i18n("Center Zone"), accent: "#8b5cf6" },
                        { id: "right",  title: i18n("Right Zone"),  accent: "#10b981" }
                    ]

                    Rectangle {
                        required property var modelData
                        readonly property string summary: page.zoneSummary(modelData.id)
                        readonly property bool   isEmpty: summary === i18n("Empty")

                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 6
                        color:  Qt.rgba(128/255, 128/255, 128/255, 0.12)
                        border.width: 1
                        border.color: isEmpty ? Qt.rgba(128/255, 128/255, 128/255, 0.18) : Qt.rgba(128/255, 128/255, 128/255, 0.30)
                        opacity: zonePreviewBar.isFullWidthBar ? 1.0 : 0.65

                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: 3
                            radius: 1.5
                            color: modelData.accent
                            opacity: isEmpty ? 0.3 : 0.9
                        }

                        Column {
                            anchors.centerIn: parent
                            anchors.topMargin: 2
                            width: parent.width - 8
                            spacing: 1

                            QC.Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.title
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.7
                            }
                            QC.Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: summary
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                opacity: isEmpty ? 0.45 : 0.95
                            }
                        }
                    }
                }
            }

            QC.Label {
                visible: !fullWidthSwitch.checked
                text: i18n("Compact pill mode: uses Left → Right order below (turn on Full-width bar above to split into 3 zones).")
                font.pixelSize: 10
                opacity: 0.65
                Layout.preferredWidth: 356
                wrapMode: Text.WordWrap
            }

            Item {
                id: orderListBox
                readonly property int rowHeight: 34
                readonly property int rowGap:    4
                readonly property int rowStep:   rowHeight + rowGap
                property int  dragIdx:   -1
                property real ghostY:    0
                property real grabOffY:  17

                implicitWidth:  356
                implicitHeight: Math.max(rowHeight, page.orderKeys.length * rowStep - rowGap)
                Layout.preferredWidth:  implicitWidth
                Layout.preferredHeight: implicitHeight

                Column {
                    id: orderColumn
                    width: parent.width
                    spacing: orderListBox.rowGap

                    Repeater {
                        model: page.orderKeys.length

                        Rectangle {
                            id: slotCard
                            required property int index
                            readonly property string itemKey: page.orderKeys[index] || "clock"
                            readonly property string itemZone: page.zoneMap[itemKey] || "left"
                            readonly property var    itemMeta: page.widgetCatalog[itemKey] || ({ label: itemKey, icon: "configure" })
                            readonly property bool   isDragSlot: orderListBox.dragIdx === index
                            readonly property bool   rowHovered: dragArea.containsMouse || upBtn.hovered || downBtn.hovered
                            readonly property bool   moduleEnabled: itemKey === "weather" ? (typeof plasmoid !== "undefined" && plasmoid.configuration ? plasmoid.configuration.showWeatherWidget : true)
                                                                  : (itemKey === "workspace" ? workspaceSwitch.checked
                                                                  : (itemKey === "media" ? mediaSwitch.checked
                                                                  : (itemKey === "status" ? statusSwitch.checked : true)))

                            width:  orderColumn.width
                            height: orderListBox.rowHeight
                            radius: 7
                            color:  isDragSlot
                                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.10)
                                    : (rowHovered
                                       ? Qt.rgba(128/255, 128/255, 128/255, 0.20)
                                       : Qt.rgba(128/255, 128/255, 128/255, 0.11))
                            border.width: 1
                            border.color: isDragSlot
                                          ? Kirigami.Theme.highlightColor
                                          : Qt.rgba(128/255, 128/255, 128/255, 0.24)
                            opacity: moduleEnabled ? 1.0 : 0.55

                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                id: slotRow
                                anchors.fill: parent
                                anchors.leftMargin:  10
                                anchors.rightMargin: 6
                                spacing: 6
                                opacity: slotCard.isDragSlot ? 0.25 : 1.0

                                QC.Label {
                                    text: "☰"
                                    font.pixelSize: 12
                                    opacity: 0.55
                                }

                                QC.Label {
                                    text: (slotCard.index + 1) + "."
                                    font.pixelSize: 11
                                    font.bold: true
                                    opacity: 0.65
                                    Layout.preferredWidth: 14
                                }

                                Kirigami.Icon {
                                    source: slotCard.itemMeta.icon
                                    Layout.preferredWidth:  15
                                    Layout.preferredHeight: 15
                                }

                                QC.Label {
                                    text: slotCard.itemMeta.label
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // 3-Zone selector pills [L] [C] [R]
                                Row {
                                    id: zoneBtnRow
                                    spacing: 2

                                    Repeater {
                                        model: [
                                            { id: "left",   code: "L", tip: i18n("Place in Left Zone"),   col: "#3b82f6" },
                                            { id: "center", code: "C", tip: i18n("Place in Center Zone"), col: "#8b5cf6" },
                                            { id: "right",  code: "R", tip: i18n("Place in Right Zone"),  col: "#10b981" }
                                        ]

                                        Rectangle {
                                            required property var modelData
                                            readonly property bool active: slotCard.itemZone === modelData.id

                                            width: 22; height: 22; radius: 5
                                            color: active
                                                   ? modelData.col
                                                   : (zMouse.containsMouse ? Qt.rgba(128/255, 128/255, 128/255, 0.28) : Qt.rgba(128/255, 128/255, 128/255, 0.14))
                                            border.width: active ? 0 : 1
                                            border.color: Qt.rgba(128/255, 128/255, 128/255, 0.25)

                                            QC.Label {
                                                anchors.centerIn: parent
                                                text: modelData.code
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: active ? "#ffffff" : Kirigami.Theme.textColor
                                                opacity: active ? 1.0 : 0.72
                                            }

                                            MouseArea {
                                                id: zMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: page.setWidgetZone(slotCard.itemKey, modelData.id)
                                            }

                                            QC.ToolTip.visible: zMouse.containsMouse
                                            QC.ToolTip.text:    modelData.tip
                                            QC.ToolTip.delay:   400
                                        }
                                    }
                                }

                                Row {
                                    id: btnRow
                                    spacing: 1

                                    QC.ToolButton {
                                        id: upBtn
                                        implicitWidth:  22
                                        implicitHeight: 22
                                        text: "↑"
                                        enabled: slotCard.index > 0
                                        onClicked: page.moveOrderItem(slotCard.index, slotCard.index - 1)
                                    }
                                    QC.ToolButton {
                                        id: downBtn
                                        implicitWidth:  22
                                        implicitHeight: 22
                                        text: "↓"
                                        enabled: slotCard.index < page.orderKeys.length - 1
                                        onClicked: page.moveOrderItem(slotCard.index, slotCard.index + 1)
                                    }
                                }
                            }

                            MouseArea {
                                id: dragArea
                                anchors {
                                    left:   parent.left
                                    top:    parent.top
                                    bottom: parent.bottom
                                    right:  parent.right
                                    rightMargin: zoneBtnRow.width + btnRow.width + 16
                                }
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                property real startY: 0
                                property bool dragging: false

                                onPressed: function(mouse) {
                                    const pt = mapToItem(orderListBox, mouse.x, mouse.y)
                                    startY = pt.y
                                    dragging = false
                                    orderListBox.grabOffY = Math.max(4, Math.min(orderListBox.rowHeight - 4, mouse.y))
                                }

                                onPositionChanged: function(mouse) {
                                    if (!pressed) return
                                    const pt = mapToItem(orderListBox, mouse.x, mouse.y)
                                    if (!dragging) {
                                        if (Math.abs(pt.y - startY) < 4) return
                                        dragging = true
                                        orderListBox.dragIdx = slotCard.index
                                    }
                                    const maxY = Math.max(0, orderListBox.height - orderListBox.rowHeight)
                                    orderListBox.ghostY = Math.max(0, Math.min(maxY, pt.y - orderListBox.grabOffY))
                                    const centerY = orderListBox.ghostY + orderListBox.rowHeight * 0.5
                                    const hoverIdx = Math.max(0, Math.min(page.orderKeys.length - 1, Math.floor(centerY / orderListBox.rowStep)))
                                    if (orderListBox.dragIdx >= 0 && hoverIdx !== orderListBox.dragIdx) {
                                        const fromIdx = orderListBox.dragIdx
                                        orderListBox.dragIdx = hoverIdx
                                        page.moveOrderItem(fromIdx, hoverIdx)
                                    }
                                }

                                onReleased: {
                                    dragging = false
                                    orderListBox.dragIdx = -1
                                }
                                onCanceled: {
                                    dragging = false
                                    orderListBox.dragIdx = -1
                                }
                            }
                        }
                    }
                }

                // Floating preview pill rendered smoothly under cursor while dragging
                Rectangle {
                    id: dragGhost
                    readonly property string ghostKey: orderListBox.dragIdx >= 0 ? (page.orderKeys[orderListBox.dragIdx] || "clock") : "clock"
                    readonly property var    ghostMeta: page.widgetCatalog[ghostKey] || ({ label: "", icon: "configure" })

                    visible: orderListBox.dragIdx >= 0
                    z:       20
                    x:       0
                    y:       orderListBox.ghostY
                    width:   orderListBox.width
                    height:  orderListBox.rowHeight
                    radius:  7
                    color:   Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.28)
                    border.width: 1
                    border.color: Kirigami.Theme.highlightColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin:  10
                        anchors.rightMargin: 10
                        spacing: 7

                        QC.Label {
                            text: "☰"
                            font.pixelSize: 12
                            opacity: 0.85
                        }

                        QC.Label {
                            text: (orderListBox.dragIdx + 1) + "."
                            font.pixelSize: 11
                            font.bold: true
                            Layout.preferredWidth: 14
                        }

                        Kirigami.Icon {
                            source: dragGhost.ghostMeta.icon
                            Layout.preferredWidth:  15
                            Layout.preferredHeight: 15
                        }

                        QC.Label {
                            text: dragGhost.ghostMeta.label
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            RowLayout {
                Layout.preferredWidth: 356
                spacing: 8

                QC.Label {
                    text: i18n("Drag / ↑↓ to reorder • L / C / R sets zone")
                    font.pixelSize: 11
                    opacity: 0.65
                    Layout.fillWidth: true
                }

                QC.Button {
                    text: i18n("Reset")
                    flat: true
                    enabled: page.cfg_widgetOrder !== page.defaultOrder.join(",")
                             || page.cfg_widgetZones !== page.defaultZonesStr
                    onClicked: page.commitOrderAndZones(page.defaultOrder.slice(), Object.assign({}, page.defaultZoneMap))
                }
            }
        }

        // ── Workspace ─────────────────────────────────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("🖥  Workspace Switcher")
        }

        QC.Switch {
            id: workspaceSwitch
            Kirigami.FormData.label: i18n("Show workspace switcher")
        }

        QC.Switch {
            id: hideEmptySwitch
            Kirigami.FormData.label: i18n("Hide empty workspaces")
            enabled: workspaceSwitch.checked
        }

        // ── Media ─────────────────────────────────────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("🎵  Media Player")
        }

        QC.Switch {
            id: mediaSwitch
            Kirigami.FormData.label: i18n("Show media player widget")
        }

        QC.Switch {
            id: autoHideSwitch
            Kirigami.FormData.label: i18n("Auto-hide when no media playing")
            enabled: mediaSwitch.checked
        }

        // ── Status ────────────────────────────────────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("📊  System Status")
        }

        QC.Switch {
            id: statusSwitch
            Kirigami.FormData.label: i18n("Show system status widget")
        }

        QC.SpinBox {
            id: refreshSpin
            from: 1; to: 30; stepSize: 1
            editable: true
            Kirigami.FormData.label: i18n("Refresh interval")
            enabled: statusSwitch.checked
            textFromValue: function(value) { return i18n("%1 sec", value) }
        }

        // Connectivity group
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Connectivity")
        }

        QC.Switch {
            id: netSwitch
            Kirigami.FormData.label: i18n("Wi-Fi (SSID badge)")
            enabled: statusSwitch.checked
        }

        QC.Switch {
            id: btSwitch
            Kirigami.FormData.label: i18n("Bluetooth badge")
            enabled: statusSwitch.checked
        }

        // System group
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("System")
        }

        QC.Switch {
            id: batSwitch
            Kirigami.FormData.label: i18n("Battery % (hidden on desktop)")
            enabled: statusSwitch.checked
        }

        QC.Switch {
            id: volSwitch
            Kirigami.FormData.label: i18n("Volume %")
            enabled: statusSwitch.checked
        }

        // Hardware group
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Hardware Monitor")
        }

        QC.Switch {
            id: netSpeedSwitch
            Kirigami.FormData.label: i18n("Network speed")
            enabled: statusSwitch.checked
        }

        QC.Switch {
            id: cpuSwitch
            Kirigami.FormData.label: i18n("CPU usage %")
            enabled: statusSwitch.checked
        }

        QC.Switch {
            id: tempSwitch
            Kirigami.FormData.label: i18n("CPU temperature °C")
            enabled: statusSwitch.checked
        }

        QC.Switch {
            id: ramSwitch
            Kirigami.FormData.label: i18n("RAM usage %")
            enabled: statusSwitch.checked
        }

        // Actions group
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Quick Actions")
        }

        QC.Switch {
            id: actionsSwitch
            Kirigami.FormData.label: i18n("Show Settings & KRunner buttons")
            enabled: statusSwitch.checked
        }
    }
}
