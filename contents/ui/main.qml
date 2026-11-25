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
    readonly property bool   fullWidth:   plasmoid.configuration.pillFullWidth
    readonly property bool   isLight:     plasmoid.configuration.themeMode === "light"
    readonly property string bgColor:     /^#[0-9a-fA-F]{6}$/.test(plasmoid.configuration.pillBackground)
                                          ? plasmoid.configuration.pillBackground : (isLight ? "#f4f4f5" : "#1e1f22")
    readonly property string accent:      /^#[0-9a-fA-F]{6}$/.test(plasmoid.configuration.accentColor)
                                          ? plasmoid.configuration.accentColor : "#8b5cf6"
    readonly property color  dividerCol:  isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.12)

    // ── Visual Layout ─────────────────────────────────────────────
    fullRepresentation: Item {
        id: fullRep

        readonly property real minNeededWidth: contentArea.compactWidth + 44
        implicitWidth:  root.fullWidth
                        ? Math.max(minNeededWidth, (Screen.width > 0 ? Screen.width - 16 : 1280))
                        : Math.max(120, contentArea.compactWidth + 36)
        implicitHeight: Math.max(54, contentArea.height + 22)

        Layout.fillWidth:       root.fullWidth
        Layout.preferredWidth:  root.fullWidth ? -1 : implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth:    Math.max(120, minNeededWidth)
        Layout.minimumHeight:   48

        // Glassmorphism pill background
        Rectangle {
            id: pill
            anchors {
                fill:         contentArea
                leftMargin:   -14
                rightMargin:  -14
                topMargin:    -6
                bottomMargin: -6
            }
            radius:  root.pillRadius
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

        // 3-Zone Content Area (Left | Center Media | Right Status) or Compact Sequential Row
        Item {
            id: contentArea
            readonly property real gap:        12
            readonly property real mediaDivW:  (!root.fullWidth && mediaWidget.visible) ? (1 + gap * 2) : 0
            readonly property real statusDivW: (!root.fullWidth && statusWidget.visible) ? (1 + gap * 2) : 0
            readonly property real compactWidth: leftZone.implicitWidth
                                                 + (mediaWidget.visible ? (root.fullWidth ? gap : mediaDivW) + mediaWidget.implicitWidth : 0)
                                                 + (statusWidget.visible ? (root.fullWidth ? gap : statusDivW) + statusWidget.implicitWidth : 0)

            width:  root.fullWidth ? Math.max(compactWidth, fullRep.width - 44) : compactWidth
            height: Math.max(leftZone.implicitHeight, mediaWidget.implicitHeight, statusWidget.implicitHeight)
            anchors.centerIn: parent

            // ── Zone 1 (Left): Clock | Weather | Workspaces ──────
            Row {
                id: leftZone
                x:  0
                anchors.verticalCenter: parent.verticalCenter
                spacing: contentArea.gap

                ClockWidget {
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 1; height: 18
                    color: root.dividerCol
                    visible: weatherWidget.showWidget || workspaceWidget.showWidget
                    anchors.verticalCenter: parent.verticalCenter
                }

                WeatherWidget {
                    id: weatherWidget
                    anchors.verticalCenter: parent.verticalCenter
                }

                WorkspaceWidget {
                    id: workspaceWidget
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Divider before media (compact mode only)
            Rectangle {
                width: 1; height: 18
                color: root.dividerCol
                visible: !root.fullWidth && mediaWidget.visible
                x: leftZone.width + contentArea.gap
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── Zone 2 (Center): Media Player ────────────────────
            MediaWidget {
                id: mediaWidget
                readonly property real minX:    leftZone.width + contentArea.gap
                readonly property real maxX:    contentArea.width - (statusWidget.visible ? statusWidget.width + contentArea.gap : 0) - width
                readonly property real centerX: (contentArea.width - width) / 2

                x: root.fullWidth
                   ? Math.max(minX, Math.min(maxX, centerX))
                   : (leftZone.width + contentArea.mediaDivW)
                anchors.verticalCenter: parent.verticalCenter
            }

            // Divider before status (compact mode only)
            Rectangle {
                width: 1; height: 18
                color: root.dividerCol
                visible: !root.fullWidth && statusWidget.visible
                x: (mediaWidget.visible ? (mediaWidget.x + mediaWidget.width) : leftZone.width) + contentArea.gap
                anchors.verticalCenter: parent.verticalCenter
            }

            // ── Zone 3 (Right): System Status ────────────────────
            StatusWidget {
                id: statusWidget
                x: root.fullWidth
                   ? (contentArea.width - width)
                   : ((mediaWidget.visible ? (mediaWidget.x + mediaWidget.width) : leftZone.width) + contentArea.statusDivW)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
