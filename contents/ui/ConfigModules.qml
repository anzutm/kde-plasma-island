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

    // Widget order (comma-separated canonical keys)
    property string cfg_widgetOrder: "clock,weather,workspace,media,status"
    property bool   _syncingOrder:   false

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
        "clock":     { label: i18n("Clock"),         icon: "clock" },
        "weather":   { label: i18n("Weather"),       icon: "weather-few-clouds-symbolic" },
        "workspace": { label: i18n("Workspaces"),    icon: "view-grid-symbolic" },
        "media":     { label: i18n("Media Player"),  icon: "media-playback-start-symbolic" },
        "status":    { label: i18n("System Status"), icon: "preferences-system-symbolic" }
    })
    readonly property var defaultOrder: ["clock", "weather", "workspace", "media", "status"]

    ListModel {
        id: orderModel
    }

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

    function loadOrderFromConfig() {
        if (_syncingOrder) return
        const keys = normalizeOrder(cfg_widgetOrder)
        let same = (orderModel.count === keys.length)
        if (same) {
            for (let i = 0; i < keys.length; i++) {
                if (orderModel.get(i).key !== keys[i]) {
                    same = false
                    break
                }
            }
        }
        if (same) return

        _syncingOrder = true
        orderModel.clear()
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i]
            const meta = widgetCatalog[k]
            orderModel.append({ key: k, label: meta.label, iconName: meta.icon })
        }
        _syncingOrder = false
    }

    function commitOrder() {
        if (_syncingOrder) return
        const keys = []
        for (let i = 0; i < orderModel.count; i++) {
            keys.push(orderModel.get(i).key)
        }
        const next = keys.join(",")
        if (cfg_widgetOrder !== next) {
            _syncingOrder = true
            cfg_widgetOrder = next
            _syncingOrder = false
        }
    }

    function moveOrderItem(fromIdx, toIdx) {
        if (fromIdx < 0 || toIdx < 0 || fromIdx >= orderModel.count || toIdx >= orderModel.count || fromIdx === toIdx) {
            return
        }
        orderModel.move(fromIdx, toIdx, 1)
        commitOrder()
    }

    onCfg_widgetOrderChanged: loadOrderFromConfig()
    Component.onCompleted:    loadOrderFromConfig()

    Kirigami.FormLayout {

        // ── Widget Order (Drag & Drop or Move Buttons) ────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("🔀  Widget Order")
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Left → Right")
            spacing: 6

            Item {
                id: orderListBox
                readonly property int rowHeight: 34
                readonly property int rowGap:    4
                readonly property int rowStep:   rowHeight + rowGap

                implicitWidth:  300
                implicitHeight: Math.max(rowHeight, orderModel.count * rowStep - rowGap)
                Layout.preferredWidth:  implicitWidth
                Layout.preferredHeight: implicitHeight

                Repeater {
                    model: orderModel

                    Item {
                        id: delegateRoot
                        required property int    index
                        required property string key
                        required property string label
                        required property string iconName

                        readonly property bool rowHovered: dragArea.containsMouse || upBtn.hovered || downBtn.hovered
                        readonly property real targetY: index * orderListBox.rowStep
                        readonly property bool moduleEnabled: key === "weather" ? (typeof plasmoid !== "undefined" && plasmoid.configuration ? plasmoid.configuration.showWeatherWidget : true)
                                                            : (key === "workspace" ? workspaceSwitch.checked
                                                            : (key === "media" ? mediaSwitch.checked
                                                            : (key === "status" ? statusSwitch.checked : true)))

                        width:  orderListBox.width
                        height: orderListBox.rowHeight
                        z:      dragArea.drag.active ? 10 : 1

                        Component.onCompleted: y = targetY
                        onTargetYChanged: {
                            if (!dragArea.drag.active) snapAnim.restart()
                        }
                        onYChanged: {
                            if (!dragArea.drag.active) return
                            const targetIdx = Math.max(0, Math.min(orderModel.count - 1, Math.round(y / orderListBox.rowStep)))
                            if (targetIdx !== delegateRoot.index) {
                                page.moveOrderItem(delegateRoot.index, targetIdx)
                            }
                        }

                        NumberAnimation {
                            id: snapAnim
                            target:   delegateRoot
                            property: "y"
                            to:       delegateRoot.targetY
                            duration: 140
                            easing.type: Easing.OutCubic
                        }

                        Rectangle {
                            id: rowCard
                            anchors.fill: parent
                            radius: 7
                            color:  dragArea.drag.active
                                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.20)
                                    : (delegateRoot.rowHovered
                                       ? Qt.rgba(128/255, 128/255, 128/255, 0.20)
                                       : Qt.rgba(128/255, 128/255, 128/255, 0.11))
                            border.width: 1
                            border.color: dragArea.drag.active
                                          ? Kirigami.Theme.highlightColor
                                          : Qt.rgba(128/255, 128/255, 128/255, 0.24)
                            opacity: delegateRoot.moduleEnabled ? 1.0 : 0.55

                            Behavior on color { ColorAnimation { duration: 100 } }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                drag.target:    delegateRoot
                                drag.axis:      Drag.YAxis
                                drag.threshold: 4
                                drag.smoothed:  false
                                drag.minimumY:  0
                                drag.maximumY:  Math.max(0, (orderModel.count - 1) * orderListBox.rowStep)
                                onReleased: snapAnim.restart()
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin:  10
                                anchors.rightMargin: 6
                                spacing: 7

                                QC.Label {
                                    text: "☰"
                                    font.pixelSize: 12
                                    opacity: 0.55
                                }

                                QC.Label {
                                    text: (delegateRoot.index + 1) + "."
                                    font.pixelSize: 11
                                    font.bold: true
                                    opacity: 0.65
                                    Layout.preferredWidth: 14
                                }

                                Kirigami.Icon {
                                    source: delegateRoot.iconName
                                    Layout.preferredWidth:  15
                                    Layout.preferredHeight: 15
                                }

                                QC.Label {
                                    text: delegateRoot.label
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                QC.Label {
                                    visible: delegateRoot.index === 0 || delegateRoot.index === orderModel.count - 1
                                    text: delegateRoot.index === 0 ? i18n("Left") : i18n("Right")
                                    font.pixelSize: 10
                                    opacity: 0.6
                                }

                                Row {
                                    spacing: 2
                                    z: 2

                                    QC.ToolButton {
                                        id: upBtn
                                        implicitWidth:  24
                                        implicitHeight: 24
                                        text: "↑"
                                        enabled: delegateRoot.index > 0
                                        onClicked: page.moveOrderItem(delegateRoot.index, delegateRoot.index - 1)
                                    }
                                    QC.ToolButton {
                                        id: downBtn
                                        implicitWidth:  24
                                        implicitHeight: 24
                                        text: "↓"
                                        enabled: delegateRoot.index < orderModel.count - 1
                                        onClicked: page.moveOrderItem(delegateRoot.index, delegateRoot.index + 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.preferredWidth: 300
                spacing: 8

                QC.Label {
                    text: i18n("Drag rows or use ↑ / ↓ to reorder")
                    font.pixelSize: 11
                    opacity: 0.65
                    Layout.fillWidth: true
                }

                QC.Button {
                    text: i18n("Reset")
                    flat: true
                    enabled: page.cfg_widgetOrder !== page.defaultOrder.join(",")
                    onClicked: page.cfg_widgetOrder = page.defaultOrder.join(",")
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
