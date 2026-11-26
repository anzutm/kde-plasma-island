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
    readonly property real   cfgScale:    Math.min(1.5, Math.max(0.75, plasmoid.configuration.widgetScale || 1.0))
    readonly property bool   fullWidth:   plasmoid.configuration.pillFullWidth
    readonly property bool   isLight:     plasmoid.configuration.themeMode === "light"
    readonly property string bgColor:     /^#[0-9a-fA-F]{6}$/.test(plasmoid.configuration.pillBackground)
                                          ? plasmoid.configuration.pillBackground : (isLight ? "#f4f4f5" : "#1e1f22")
    readonly property string accent:      /^#[0-9a-fA-F]{6}$/.test(plasmoid.configuration.accentColor)
                                          ? plasmoid.configuration.accentColor : "#8b5cf6"
    readonly property color  dividerCol:  isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.12)

    // Unscaled 1.0x compact content width estimate (avoids binding loops when scaling with container size)
    property real _stableBaseWidth: 960

    // ── Visual Layout ─────────────────────────────────────────────
    fullRepresentation: Item {
        id: fullRep

        // Responsive scale follows desktop Edit Mode resize handles while preventing horizontal cutoff
        readonly property real fitW:    (fullRep.width > 0)
                                        ? Math.max(0.55, (fullRep.width - 20) / Math.max(120, root._stableBaseWidth + 40))
                                        : root.cfgScale
        readonly property real fitH:    (fullRep.height > 0)
                                        ? Math.max(0.55, (fullRep.height - 6) / 48)
                                        : root.cfgScale
        readonly property real boxFit:  Math.min(2.2, fitW, fitH)
        readonly property real uiScale: Math.max(0.55, Math.min(2.2, fitW, fitH,
                                            root.cfgScale < 1.0 ? boxFit * root.cfgScale : Math.max(boxFit, root.cfgScale)))

        readonly property int hPad: Math.round(14 * fullRep.uiScale)
        readonly property int vPad: Math.round(5 * fullRep.uiScale)
        implicitWidth:  root.fullWidth
                        ? Math.max(Math.ceil((root._stableBaseWidth + 44) * root.cfgScale), (Screen.width > 0 ? Screen.width - 32 : 1280))
                        : Math.max(240, Math.ceil((root._stableBaseWidth + 36) * root.cfgScale))
        implicitHeight: Math.max(44, Math.round(56 * root.cfgScale))

        Layout.fillWidth:       root.fullWidth
        Layout.preferredWidth:  implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth:    root.cfgScale > 1.0
                                ? Math.min(Screen.width > 0 ? Screen.width - 16 : 1900, Math.ceil((root._stableBaseWidth + 44) * root.cfgScale))
                                : Math.max(280, Math.ceil((root._stableBaseWidth + 40) * 0.55 + 20))
        Layout.minimumHeight:   root.cfgScale > 1.0 ? Math.min(96, Math.round(56 * root.cfgScale)) : 36

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

                const isInfo = (k) => (k === "clock" || k === "weather" || k === "workspace")
                const needsDiv = (a, b) => !((a === "weather" && b === "workspace") || (a === "workspace" && b === "weather"))

                // Calculate tight sequential layout (compact mode & 1.0x width measurement)
                const compactX = {}
                const compactDivs = []
                let cx = 0
                for (let i = 0; i < visKeys.length; i++) {
                    const k = visKeys[i]
                    if (i > 0) {
                        const prev = visKeys[i - 1]
                        if (needsDiv(prev, k)) {
                            compactDivs.push(cx + gap)
                            cx += gap * 2 + 1
                        } else {
                            cx += gap
                        }
                    }
                    compactX[k] = cx
                    cx += infoMap[k].w
                }
                const tightWidth = cx

                if (!root.fullWidth) {
                    return { x: compactX, divs: compactDivs, compactWidth: tightWidth }
                }

                const fullX = {}
                const fullDivs = []
                const availW = Math.max(tightWidth, fullRep.width - fullRep.hPad * 2 - 16)

                // Group adjacent {clock, weather, workspace} into clusters while preserving order
                const clusters = []
                for (let i = 0; i < visKeys.length; i++) {
                    const k = visKeys[i]
                    if (clusters.length > 0 && isInfo(k) && isInfo(clusters[clusters.length - 1].keys[0])) {
                        clusters[clusters.length - 1].keys.push(k)
                    } else {
                        clusters.push({ keys: [k] })
                    }
                }

                // Measure each cluster's internal width and relative offsets
                for (let c = 0; c < clusters.length; c++) {
                    const keys = clusters[c].keys
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
                    clusters[c].w = rx
                    clusters[c].rel = rel
                    clusters[c].divs = divs
                }

                // Position clusters across full-width pill (1: center, 2: ends, 3: 3-zone, 4+: even)
                const clusterX = new Array(clusters.length)
                if (clusters.length === 1) {
                    clusterX[0] = Math.max(0, (availW - clusters[0].w) / 2)
                } else if (clusters.length === 2) {
                    clusterX[0] = 0
                    clusterX[1] = Math.max(clusters[0].w + gap, availW - clusters[1].w)
                } else if (clusters.length === 3) {
                    clusterX[0] = 0
                    clusterX[2] = Math.max(0, availW - clusters[2].w)
                    const minMid = clusters[0].w + gap
                    const maxMid = clusterX[2] - gap - clusters[1].w
                    const idealMid = (availW - clusters[1].w) / 2
                    clusterX[1] = Math.max(minMid, Math.min(maxMid, idealMid))
                } else if (clusters.length >= 4) {
                    let sumW = 0
                    for (let c = 0; c < clusters.length; c++) sumW += clusters[c].w
                    const evenGap = Math.max(gap, (availW - sumW) / (clusters.length - 1))
                    let px = 0
                    for (let c = 0; c < clusters.length; c++) {
                        clusterX[c] = (c === clusters.length - 1) ? Math.max(px, availW - clusters[c].w) : px
                        px = clusterX[c] + clusters[c].w + evenGap
                    }
                }

                for (let c = 0; c < clusters.length; c++) {
                    const base = clusterX[c]
                    const keys = clusters[c].keys
                    for (let i = 0; i < keys.length; i++) {
                        fullX[keys[i]] = base + clusters[c].rel[keys[i]]
                    }
                    for (let d = 0; d < clusters[c].divs.length; d++) {
                        fullDivs.push(base + clusters[c].divs[d])
                    }
                }

                return { x: fullX, divs: fullDivs, compactWidth: tightWidth }
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
                    ? Math.max(100, fullRep.width - fullRep.hPad * 2 - 16)
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
