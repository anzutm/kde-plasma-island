// WorkspaceWidget.qml — Plasma Island for KDE Plasma 6
// Native KDE TaskManager integration: 0ms reactivity, zero polling subprocesses, supports Hide Empty Workspaces
import QtQuick
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager

Item {
    id: root

    readonly property bool showWidget: plasmoid.configuration.showWorkspaceWidget
    readonly property bool hideEmpty:  plasmoid.configuration.workspaceHideEmpty
    readonly property bool isLight:    plasmoid.configuration.themeMode === "light"
    property real uiScale: 1.0
    visible:        showWidget
    implicitWidth:  showWidget ? pillRow.implicitWidth + Math.round(16 * uiScale) : 0
    implicitHeight: Math.round(34 * uiScale)

    property var nonEmptyMap: ({})

    TaskManager.VirtualDesktopInfo {
        id: vdi
    }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        onRowsInserted: refreshNonEmpty()
        onRowsRemoved:  refreshNonEmpty()
        onDataChanged:  refreshNonEmpty()
        onModelReset:   refreshNonEmpty()
        Component.onCompleted: refreshNonEmpty()
    }

    function refreshNonEmpty() {
        const map = {}
        const n = tasksModel.count
        for (let i = 0; i < n; i++) {
            const idx = tasksModel.index(i, 0)
            const onAll = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops)
            if (onAll) {
                const ids = vdi.desktopIds
                for (let j = 0; j < ids.length; j++) map[String(ids[j])] = true
                break
            }
            const vds = tasksModel.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops)
            if (vds && vds.length) {
                for (let j = 0; j < vds.length; j++) map[String(vds[j])] = true
            }
        }
        root.nonEmptyMap = map
    }

    readonly property int currentIndex: {
        const ids = vdi.desktopIds || []
        const cur = String(vdi.currentDesktop || "")
        const idx = ids.findIndex(id => String(id) === cur)
        return idx >= 0 ? idx : 0
    }

    // Tracked Plasma 6 compatibility dependency (plasma5support executable engine)
    P5Support.DataSource {
        id: kwin
        engine: "executable"
        connectedSources: []
        onNewData: function(source) { disconnectSource(source) }
    }

    function switchTo(index) {
        const ids = vdi.desktopIds || []
        if (index < 0 || index >= ids.length) return
        const uuid = String(ids[index] || "")
        // Validate desktop ID characters before shell interpolation
        if (!/^[0-9a-zA-Z_{}-]+$/.test(uuid) || uuid === String(vdi.currentDesktop || "")) return
        kwin.connectSource(
            `qdbus6 org.kde.KWin /VirtualDesktopManager ` +
            `org.freedesktop.DBus.Properties.Set ` +
            `org.kde.KWin.VirtualDesktopManager current "${uuid}" >/dev/null 2>&1 &`
        )
    }

    function cycleWorkspace(delta) {
        const ids = vdi.desktopIds || []
        if (ids.length <= 1) return
        const visibleIndices = []
        for (let i = 0; i < ids.length; i++) {
            const idStr = String(ids[i])
            if (!root.hideEmpty || i === root.currentIndex || root.nonEmptyMap[idStr]) {
                visibleIndices.push(i)
            }
        }
        const pos = visibleIndices.indexOf(root.currentIndex)
        if (pos < 0) return
        const nextPos = Math.max(0, Math.min(visibleIndices.length - 1, pos + delta))
        root.switchTo(visibleIndices[nextPos])
    }

    // Scroll wheel gesture to cycle workspaces anywhere on widget
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            if (event.angleDelta.y > 0) root.cycleWorkspace(-1)
            else if (event.angleDelta.y < 0) root.cycleWorkspace(1)
        }
    }

    Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: Math.round(5 * root.uiScale)

        Repeater {
            model: vdi.desktopIds ? vdi.desktopIds.length : 0

            Rectangle {
                id: ws
                readonly property string vdId:      String((vdi.desktopIds && vdi.desktopIds[index]) || "")
                readonly property bool   isCurrent: vdId !== "" && vdId === String(vdi.currentDesktop || "")
                readonly property bool   hasWin:    !!root.nonEmptyMap[vdId]
                readonly property int    btnSize:   Math.round(24 * root.uiScale)

                visible: !root.hideEmpty || isCurrent || hasWin

                // Symmetrical circles guarantee zero layout shift and zero overlapping
                width:  visible ? btnSize : 0
                height: btnSize
                radius: btnSize / 2
                color:  isCurrent
                        ? (root.isLight ? "#18181b" : "#ffffff")
                        : (root.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.12))

                Behavior on color { ColorAnimation { duration: 180 } }

                // Hover overlay
                Rectangle {
                    anchors.fill: parent
                    radius:       parent.radius
                    color:        root.isLight
                                  ? Qt.rgba(0, 0, 0, wsArea.containsMouse && !ws.isCurrent ? 0.10 : 0)
                                  : Qt.rgba(1, 1, 1, wsArea.containsMouse && !ws.isCurrent ? 0.14 : 0)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                PC3.Label {
                    anchors.centerIn: parent
                    text:             index + 1
                    font.pixelSize:   Math.round(11 * root.uiScale)
                    font.weight:      ws.isCurrent ? Font.Bold : Font.DemiBold
                    color:            ws.isCurrent
                                      ? (root.isLight ? "#ffffff" : "#1e1f22")
                                      : (root.isLight ? Qt.rgba(0, 0, 0, 0.65) : Qt.rgba(1, 1, 1, 0.65))
                }

                MouseArea {
                    id:           wsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.switchTo(index)
                }

                PC3.ToolTip.visible: wsArea.containsMouse
                PC3.ToolTip.text:    (vdi.desktopNames && vdi.desktopNames[index])
                                     ? i18n("%1 (%2)", vdi.desktopNames[index], index + 1)
                                     : i18n("Workspace %1", index + 1)
                PC3.ToolTip.delay:   600
            }
        }
    }
}
