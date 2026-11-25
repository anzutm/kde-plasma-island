// ConfigAppearance.qml — Pill appearance settings for Plasma Island
// Features: Opacity slider, radius spinbox, color inputs with swatches, live preview & clean theme presets
import QtQuick
import QtQuick.Controls as QC
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // KCM auto-syncs any property named cfg_<entryName>
    property alias  cfg_pillOpacity:      opacitySlider.value
    property alias  cfg_pillBorderRadius: radiusSpin.value
    property alias  cfg_pillFullWidth:    fullWidthSwitch.checked
    property string cfg_themeMode:        "dark"
    property string cfg_pillBackground:   "#1e1f22"
    property string cfg_accentColor:      "#8b5cf6"

    onCfg_themeModeChanged: {
        themeModeCombo.currentIndex = (cfg_themeMode === "light" ? 1 : 0)
    }
    onCfg_pillBackgroundChanged: {
        if (bgField.text !== cfg_pillBackground) bgField.text = cfg_pillBackground
    }
    onCfg_accentColorChanged: {
        if (accentField.text !== cfg_accentColor) accentField.text = cfg_accentColor
    }

    Kirigami.FormLayout {
        // ── 1. Pill Style ─────────────────────────────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("🎨  Pill Style")
        }

        // Opacity slider
        RowLayout {
            Kirigami.FormData.label: i18n("Background opacity")
            spacing: 8

            QC.Slider {
                id: opacitySlider
                from: 0.0; to: 1.0; stepSize: 0.01
                Layout.preferredWidth: 180
            }
            QC.Label {
                text: Math.round(opacitySlider.value * 100) + "%"
                font.pixelSize: 12
                Layout.preferredWidth: 36
            }
        }

        // Corner radius
        QC.SpinBox {
            id: radiusSpin
            from: 0; to: 60; stepSize: 2
            Kirigami.FormData.label: i18n("Corner radius")
            textFromValue: function(value) { return i18n("%1 px", value) }
        }

        // Full-width 3-zone layout toggle
        QC.Switch {
            id: fullWidthSwitch
            Kirigami.FormData.label: i18n("Full-width bar (3-zone layout)")
        }

        // Color mode selector
        QC.ComboBox {
            id: themeModeCombo
            Kirigami.FormData.label: i18n("Color mode")
            model: [i18n("Dark Mode"), i18n("Light Mode")]
            Component.onCompleted: {
                currentIndex = page.cfg_themeMode === "light" ? 1 : 0
            }
            onActivated: {
                const nextMode = currentIndex === 1 ? "light" : "dark"
                page.cfg_themeMode = nextMode
                const darkDefaults  = ["#1e1f22", "#0d0e11", "#0f172a", "#0f1a14"]
                const lightDefaults = ["#f4f4f5", "#ffffff", "#e2e8f0", "#faf5ef", "#f8fafc", "#faf8f5"]
                if (nextMode === "light" && darkDefaults.includes(bgField.text.toLowerCase())) {
                    bgField.text = "#f4f4f5"
                } else if (nextMode === "dark" && lightDefaults.includes(bgField.text.toLowerCase())) {
                    bgField.text = "#1e1f22"
                }
            }
        }

        // Background color
        RowLayout {
            Kirigami.FormData.label: i18n("Background color")
            spacing: 8

            QC.TextField {
                id: bgField
                text: "#1e1f22"
                Layout.preferredWidth: 110
                placeholderText: "#1e1f22"
                maximumLength: 7
                validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{0,6}$/ }
                color: (/^#[0-9a-fA-F]{6}$/.test(text) || text.length === 0) ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
                onTextChanged: {
                    if (/^#[0-9a-fA-F]{6}$/.test(text)) page.cfg_pillBackground = text
                }
            }
            Rectangle {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                color: /^#[0-9a-fA-F]{6}$/.test(bgField.text) ? bgField.text : "#1e1f22"
                border.width: 1
                border.color: bgSwatchMouse.containsMouse ? Kirigami.Theme.highlightColor : Qt.rgba(0,0,0,0.35)

                MouseArea {
                    id: bgSwatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        bgColorDialog.selectedColor = /^#[0-9a-fA-F]{6}$/.test(bgField.text) ? bgField.text : "#1e1f22"
                        bgColorDialog.open()
                    }
                }
                QC.ToolTip.visible: bgSwatchMouse.containsMouse
                QC.ToolTip.text:    i18n("Click to pick background color")
                QC.ToolTip.delay:   400
            }
        }

        // Accent color
        RowLayout {
            Kirigami.FormData.label: i18n("Accent color")
            spacing: 8

            QC.TextField {
                id: accentField
                text: "#8b5cf6"
                Layout.preferredWidth: 110
                placeholderText: "#8b5cf6"
                maximumLength: 7
                validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{0,6}$/ }
                color: (/^#[0-9a-fA-F]{6}$/.test(text) || text.length === 0) ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
                onTextChanged: {
                    if (/^#[0-9a-fA-F]{6}$/.test(text)) page.cfg_accentColor = text
                }
            }
            Rectangle {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12
                color: /^#[0-9a-fA-F]{6}$/.test(accentField.text) ? accentField.text : "#8b5cf6"
                border.width: 1
                border.color: accentSwatchMouse.containsMouse ? Kirigami.Theme.highlightColor : Qt.rgba(0,0,0,0.35)

                MouseArea {
                    id: accentSwatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        accentColorDialog.selectedColor = /^#[0-9a-fA-F]{6}$/.test(accentField.text) ? accentField.text : "#8b5cf6"
                        accentColorDialog.open()
                    }
                }
                QC.ToolTip.visible: accentSwatchMouse.containsMouse
                QC.ToolTip.text:    i18n("Click to pick accent color")
                QC.ToolTip.delay:   400
            }
        }

        // ── 2. Live Preview ───────────────────────────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("👁  Preview")
        }

        Rectangle {
            id: previewBackdrop
            readonly property bool previewLight: page.cfg_themeMode === "light"
            readonly property color fgColor: previewLight ? "#18181b" : "#ffffff"

            Kirigami.FormData.label: ""
            Layout.preferredWidth:  previewPill.width  + 20
            Layout.preferredHeight: previewPill.height + 20
            radius: 10
            color:  previewLight ? "#e2e8f0" : "#0b0c10"
            border.width: 1
            border.color: previewLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)

            Item {
                id: previewPill
                anchors.centerIn: parent
                width:   fullWidthSwitch.checked ? 340 : 280
                height:  44
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                // Background capsule (only this layer uses opacitySlider.value so text remains visible at 0%)
                Rectangle {
                    anchors.fill: parent
                    radius:  radiusSpin.value
                    color:   /^#[0-9a-fA-F]{6}$/.test(bgField.text) ? bgField.text : (previewBackdrop.previewLight ? "#f4f4f5" : "#1e1f22")
                    opacity: opacitySlider.value
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    QC.Label { text: "15:20"; color: previewBackdrop.fgColor; font.pixelSize: 14; font.bold: true }

                    Rectangle {
                        Layout.preferredWidth: 1; Layout.preferredHeight: 18
                        color: previewBackdrop.previewLight ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.2)
                    }

                    QC.Label { text: "☁ 31°C"; color: previewBackdrop.fgColor; font.pixelSize: 12 }

                    Rectangle {
                        Layout.preferredWidth: 1; Layout.preferredHeight: 18
                        color: previewBackdrop.previewLight ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.2)
                    }

                    Rectangle {
                        Layout.preferredWidth: 10; Layout.preferredHeight: 10; radius: 5
                        color: /^#[0-9a-fA-F]{6}$/.test(accentField.text) ? accentField.text : "#8b5cf6"
                    }
                    QC.Label { text: i18n("Playing"); color: previewBackdrop.fgColor; font.pixelSize: 11 }
                }
            }
        }

        // ── 3. Quick Presets (Dark & Light Themes) ────────────────
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("🎨  Quick Presets")
        }

        GridLayout {
            Kirigami.FormData.label: i18n("Theme")
            columns: 4
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: [
                    { label: i18n("Dark"),   bg: "#1e1f22", accent: "#8b5cf6", mode: "dark"  },
                    { label: i18n("Darker"), bg: "#0d0e11", accent: "#3b82f6", mode: "dark"  },
                    { label: i18n("Navy"),   bg: "#0f172a", accent: "#06b6d4", mode: "dark"  },
                    { label: i18n("Forest"), bg: "#0f1a14", accent: "#22c55e", mode: "dark"  },
                    { label: i18n("Light"),  bg: "#f4f4f5", accent: "#7c3aed", mode: "light" },
                    { label: i18n("Paper"),  bg: "#ffffff", accent: "#2563eb", mode: "light" },
                    { label: i18n("Frost"),  bg: "#e2e8f0", accent: "#0284c7", mode: "light" },
                    { label: i18n("Warm"),   bg: "#faf5ef", accent: "#d97706", mode: "light" }
                ]

                Rectangle {
                    Layout.preferredWidth: 76; Layout.preferredHeight: 28; radius: 14
                    readonly property bool selected: bgField.text.toLowerCase() === modelData.bg && page.cfg_themeMode === modelData.mode
                    color:  themeArea.containsMouse
                            ? Qt.rgba(128/255, 128/255, 128/255, 0.28)
                            : (selected ? Qt.rgba(128/255, 128/255, 128/255, 0.22) : Qt.rgba(128/255, 128/255, 128/255, 0.12))
                    border.width: 1
                    border.color: selected ? modelData.accent : Qt.rgba(128/255, 128/255, 128/255, 0.28)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width:  10; height: 10; radius: 5
                            color:  modelData.bg
                            border.width: 1
                            border.color: Qt.rgba(128/255, 128/255, 128/255, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width:  5; height: 5; radius: 2.5
                            color:  modelData.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        QC.Label {
                            text:           modelData.label
                            font.pixelSize: 11
                            font.weight:    parent.parent.selected ? Font.Bold : Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: themeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            bgField.text       = modelData.bg
                            accentField.text   = modelData.accent
                            page.cfg_themeMode = modelData.mode
                        }
                    }
                }
            }
        }
    }

    Dialogs.ColorDialog {
        id: bgColorDialog
        title: i18n("Select Background Color")
        onAccepted: bgField.text = selectedColor.toString().slice(0, 7)
    }

    Dialogs.ColorDialog {
        id: accentColorDialog
        title: i18n("Select Accent Color")
        onAccepted: accentField.text = selectedColor.toString().slice(0, 7)
    }
}
