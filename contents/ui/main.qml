// main.qml — Plasma Island for KDE Plasma 6
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    // Stay in full capsule representation on desktop and panel
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property int    pillRadius:  plasmoid.configuration.pillBorderRadius
    readonly property real   pillOpacity: plasmoid.configuration.pillOpacity
    readonly property real   cfgScale:    Math.min(1.80, Math.max(0.60, plasmoid.configuration.widgetScale || 1.0))
    readonly property bool   fullWidth:   plasmoid.configuration.pillFullWidth
    readonly property bool   isLight:     plasmoid.configuration.themeMode === "light"
    readonly property string bgColor:     /^#[0-9a-fA-F]{6}$/.test(plasmoid.configuration.pillBackground)
                                          ? plasmoid.configuration.pillBackground : (isLight ? "#f4f4f5" : "#1e1f22")
    readonly property string accent:      /^#[0-9a-fA-F]{6}$/.test(plasmoid.configuration.accentColor)
                                          ? plasmoid.configuration.accentColor : "#8b5cf6"
    readonly property color  dividerCol:  isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.12)

    // Unscaled 1.0x compact content width estimate (used for X minimum width & initial size)
    property real _stableBaseWidth: 1020

    // ── Visual Layout ─────────────────────────────────────────────
    fullRepresentation: Item {
        id: fullRep

        // X width is freely resizable in Edit Mode down to content width; Y height is locked to cfgScale
        readonly property real fitW:    (fullRep.width > 0)
                                        ? Math.max(0.55, (fullRep.width - 20) / Math.max(120, root._stableBaseWidth + 40))
                                        : root.cfgScale
        readonly property real uiScale: Math.max(0.55, Math.min(root.cfgScale, fitW))

        readonly property int hPad: Math.round(14 * fullRep.uiScale)
        readonly property int vPad: Math.round(5 * fullRep.uiScale)
        implicitWidth:  root.fullWidth
                        ? Math.min(Screen.width > 0 ? Screen.width - 32 : 1440, Math.ceil((root._stableBaseWidth + 44) * root.cfgScale) + 220)
                        : Math.max(240, Math.ceil((root._stableBaseWidth + 36) * root.cfgScale))
        implicitHeight: Math.max(36, Math.round(54 * root.cfgScale))

        Layout.fillWidth:       root.fullWidth
        Layout.preferredWidth:  implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth:    Math.min(Screen.width > 0 ? Screen.width - 16 : 1900, Math.ceil((root._stableBaseWidth + 44) * root.cfgScale))
        Layout.minimumHeight:   implicitHeight
        Layout.maximumHeight:   implicitHeight

        // Glassmorphism pill background
        Rectangle {
            id: pill
            anchors {
                fill:         contentArea
                leftMargin:   -fullRep.hPad
                rightMargin:  -fullRep.hPad
                topMargin:    -fullRep.vPad
                bottomMargin: -fullRep.vPad
            }
            radius:  Math.round(root.pillRadius * fullRep.uiScale)
            color:   root.bgColor
            opacity: root.pillOpacity

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled:          true
                shadowColor:            root.isLight ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.55)
                shadowBlur:             0.7
                shadowVerticalOffset:   5
                shadowHorizontalOffset: 0
            }
        }

        // 3-Zone Content Area or Ordered Row (driven by widgetOrder config)
        Item {
            id: contentArea
            readonly property real gap: Math.round(12 * fullRep.uiScale)

            readonly property var defaultOrder: ["clock", "weather", "workspace", "media", "status"]
            readonly property var defaultZones: ({
                "clock": "left", "weather": "left", "workspace": "left", "media": "center", "status": "right"
            })
            readonly property var parsedOrder: {
                const raw = (plasmoid.configuration.widgetOrder || "").split(",").map(s => s.trim()).filter(s => s !== "")
                const valid = { "clock": true, "weather": true, "workspace": true, "media": true, "status": true }
                const seen = {}
                const out = []
                for (let i = 0; i < raw.length; i++) {
                    if (valid[raw[i]] && !seen[raw[i]]) {
                        seen[raw[i]] = true
                        out.push(raw[i])
                    }
                }
                for (let i = 0; i < defaultOrder.length; i++) {
                    if (!seen[defaultOrder[i]]) {
                        seen[defaultOrder[i]] = true
                        out.push(defaultOrder[i])
                    }
                }
                return out
            }
            readonly property var parsedZones: {
                const map = { "clock": defaultZones["clock"], "weather": defaultZones["weather"],
                              "workspace": defaultZones["workspace"], "media": defaultZones["media"],
                              "status": defaultZones["status"] }
                const validZ = { "left": true, "center": true, "right": true }
                const raw = (plasmoid.configuration.widgetZones || "").split(",")
                for (let i = 0; i < raw.length; i++) {
                    const pair = raw[i].split(":")
                    if (pair.length === 2) {
                        const k = pair[0].trim()
                        const z = pair[1].trim()
                        if (map[k] !== undefined && validZ[z]) map[k] = z
                    }
                }
                return map
            }

            // Compute positions, divider geometry, and compactWidth in one unified pass
            readonly property var layoutPlan: {
                const infoMap = {
                    "clock":     { vis: true,                  w: clockWidget.implicitWidth },
                    "weather":   { vis: weatherWidget.showWidget,   w: weatherWidget.implicitWidth },
                    "workspace": { vis: workspaceWidget.showWidget, w: workspaceWidget.implicitWidth },
                    "media":     { vis: mediaWidget.visible,   w: mediaWidget.implicitWidth },
                    "status":    { vis: statusWidget.visible,  w: statusWidget.implicitWidth }
                }

                const visKeys = []
                for (let i = 0; i < parsedOrder.length; i++) {
                    const k = parsedOrder[i]
                    if (infoMap[k] && infoMap[k].vis) visKeys.push(k)
                }

                const needsDiv = (a, b) => !((a === "weather" && b === "workspace") || (a === "workspace" && b === "weather"))

                // Helper to lay out a tight sequence of keys with internal gaps and dividers
                function packGroup(keys) {
                    const rel = {}
                    const divs = []
                    let rx = 0
                    for (let i = 0; i < keys.length; i++) {
                        const k = keys[i]
                        if (i > 0) {
                            if (needsDiv(keys[i - 1], k)) {
                                divs.push(rx + gap)
                                rx += gap * 2 + 1
                            } else {
                                rx += gap
                            }
                        }
                        rel[k] = rx
                        rx += infoMap[k].w
                    }
                    return { rel: rel, divs: divs, w: rx, keys: keys }
                }

                // Calculate tight sequential layout (compact mode & 1.0x width measurement)
                const packedAll = packGroup(visKeys)
                const tightWidth = packedAll.w

                if (!root.fullWidth) {
                    return { x: packedAll.rel, divs: packedAll.divs, compactWidth: tightWidth }
                }

                // 3-Zone layout driven explicitly by parsedZones (Left | Center | Right)
                const leftKeys = [], centerKeys = [], rightKeys = []
                for (let i = 0; i < visKeys.length; i++) {
                    const k = visKeys[i]
                    const z = parsedZones[k] || "left"
                    if (z === "left") leftKeys.push(k)
                    else if (z === "center") centerKeys.push(k)
                    else rightKeys.push(k)
                }

                const leftG   = packGroup(leftKeys)
                const centerG = packGroup(centerKeys)
                const rightG  = packGroup(rightKeys)

                const minZoneCount = (leftKeys.length > 0 ? 1 : 0) + (centerKeys.length > 0 ? 1 : 0) + (rightKeys.length > 0 ? 1 : 0)
                const minFullW = leftG.w + centerG.w + rightG.w + Math.max(0, minZoneCount - 1) * gap
                const availW = Math.max(minFullW, fullRep.width - fullRep.hPad * 2 - 16)

                const leftX   = 0
                const rightX  = rightKeys.length > 0 ? Math.max(leftG.w + (leftKeys.length > 0 ? gap : 0), availW - rightG.w) : availW
                const minMid  = leftKeys.length > 0 ? (leftX + leftG.w + gap) : 0
                const maxMid  = rightKeys.length > 0 ? (rightX - gap - centerG.w) : (availW - centerG.w)
                const centerX = centerKeys.length > 0 ? Math.max(minMid, Math.min(maxMid, (availW - centerG.w) / 2)) : 0

                const fullX = {}
                const fullDivs = []
                function emitZone(g, baseX) {
                    for (let i = 0; i < g.keys.length; i++) fullX[g.keys[i]] = baseX + g.rel[g.keys[i]]
                    for (let d = 0; d < g.divs.length; d++) fullDivs.push(baseX + g.divs[d])
                }
                emitZone(leftG, leftX)
                emitZone(centerG, centerX)
                emitZone(rightG, rightX)

                return { x: fullX, divs: fullDivs, compactWidth: minFullW }
            }

            readonly property real compactWidth: layoutPlan.compactWidth

            Timer {
                id: baseWidthTimer
                interval: 50
                repeat:   false
                onTriggered: contentArea.syncBaseWidth()
            }

            function syncBaseWidth() {
                const est = compactWidth / Math.max(0.55, fullRep.uiScale)
                if (est > 40 && Math.abs(est - root._stableBaseWidth) > 8) {
                    root._stableBaseWidth = est
                }
            }
            onCompactWidthChanged: baseWidthTimer.restart()
            Component.onCompleted: syncBaseWidth()

            width:  root.fullWidth
                    ? Math.max(compactWidth, fullRep.width - fullRep.hPad * 2 - 16)
                    : compactWidth
            height: Math.max(clockWidget.implicitHeight, weatherWidget.implicitHeight,
                             workspaceWidget.implicitHeight, mediaWidget.implicitHeight,
                             statusWidget.implicitHeight)
            anchors.centerIn: parent

            // Vertical dividers placed dynamically between separated modules
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 1
                    height: Math.round(18 * fullRep.uiScale)
                    color: root.dividerCol
                    visible: index < contentArea.layoutPlan.divs.length
                    x: visible ? contentArea.layoutPlan.divs[index] : 0
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ClockWidget {
                id: clockWidget
                uiScale: fullRep.uiScale
                x: contentArea.layoutPlan.x["clock"] || 0
                anchors.verticalCenter: parent.verticalCenter
            }

            WeatherWidget {
                id: weatherWidget
                uiScale: fullRep.uiScale
                x: contentArea.layoutPlan.x["weather"] || 0
                anchors.verticalCenter: parent.verticalCenter
            }

            WorkspaceWidget {
                id: workspaceWidget
                uiScale: fullRep.uiScale
                x: contentArea.layoutPlan.x["workspace"] || 0
                anchors.verticalCenter: parent.verticalCenter
            }

            MediaWidget {
                id: mediaWidget
                uiScale: fullRep.uiScale
                x: contentArea.layoutPlan.x["media"] || 0
                anchors.verticalCenter: parent.verticalCenter
            }

            StatusWidget {
                id: statusWidget
                uiScale: fullRep.uiScale
                x: contentArea.layoutPlan.x["status"] || 0
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
