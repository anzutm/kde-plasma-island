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
    property alias  cfg_widgetScale:      scaleSlider.value
    property string cfg_themeMode:        "dark"
    property string cfg_pillBackground:   "#1e1f22"
    property string cfg_accentColor:      "#8b5cf6"
    property bool   unsavedChanges:       liveSync.unsavedChanges

    function saveConfig() {
        liveSync.commitSaved()
    }

    LiveConfigSync {
        id: liveSync
        targetPage: page
        keys: [
            "pillOpacity", "pillBorderRadius", "widgetScale",
            "themeMode", "pillBackground", "accentColor"
        ]
    }

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

        // Widget scale slider
        RowLayout {
            Kirigami.FormData.label: i18n("Widget size")
            spacing: 8

            QC.Slider {
                id: scaleSlider
                from: 0.60; to: 1.80; stepSize: 0.05
                Layout.preferredWidth: 180
            }
            QC.Label {
                text: Math.round(scaleSlider.value * 100) + "%"
                font.pixelSize: 12
                Layout.preferredWidth: 36
            }
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
                const darkDefaults  = ["#1e1f22", "#0b0d12", "#0d0e11", "#0f172a", "#0f1a14"]
                const lightDefaults = ["#f4f4f5", "#ffffff", "#e0f2fe", "#faf3e8", "#e2e8f0", "#faf5ef"]
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

        Item {
            Kirigami.FormData.label: i18n("Live")
            implicitWidth:  328
            implicitHeight: 68
            Layout.preferredWidth:  implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.minimumWidth:    implicitWidth
            Layout.minimumHeight:   implicitHeight

            Rectangle {
                id: previewBackdrop
                readonly property bool previewLight: page.cfg_themeMode === "light"
                readonly property color fgColor: previewLight ? "#18181b" : "#ffffff"

                anchors.fill: parent
                radius: 10
                clip:   true
                color:  previewLight ? "#e2e8f0" : "#0b0c10"
                border.width: 1
                border.color: previewLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.06)

                Item {
                    id: previewPill
                    readonly property real previewScale: Math.min(1.18, Math.max(0.60, scaleSlider.value))
                    readonly property bool isFullWidthBar: (typeof plasmoid !== "undefined" && plasmoid.configuration)
                                                           ? plasmoid.configuration.pillFullWidth : false

                    anchors.centerIn: parent
                    width:   Math.round((isFullWidthBar ? 268 : 200) * previewScale)
                    height:  Math.round(44 * previewScale)
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    // Background capsule (only this layer uses opacitySlider.value so text remains visible at 0%)
                    Rectangle {
                        anchors.fill: parent
                        radius:  Math.round(radiusSpin.value * previewPill.previewScale)
                        color:   /^#[0-9a-fA-F]{6}$/.test(bgField.text) ? bgField.text : (previewBackdrop.previewLight ? "#f4f4f5" : "#1e1f22")
                        opacity: opacitySlider.value
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Math.round(10 * previewPill.previewScale)

                        QC.Label {
                            text: "15:20"
                            color: previewBackdrop.fgColor
                            font.pixelSize: Math.round(14 * previewPill.previewScale)
                            font.bold: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: Math.round(18 * previewPill.previewScale)
                            color: previewBackdrop.previewLight ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.2)
                        }

                        RowLayout {
                            spacing: Math.round(4 * previewPill.previewScale)
                            Kirigami.Icon {
                                source: "weather-few-clouds-symbolic"
                                Layout.preferredWidth: Math.round(14 * previewPill.previewScale)
                                Layout.preferredHeight: Math.round(14 * previewPill.previewScale)
                                isMask: true
                                color: previewBackdrop.fgColor
                            }
                            QC.Label {
                                text: "31°C"
                                color: previewBackdrop.fgColor
                                font.pixelSize: Math.round(12 * previewPill.previewScale)
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: Math.round(18 * previewPill.previewScale)
                            color: previewBackdrop.previewLight ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.2)
                        }

                        Rectangle {
                            readonly property int dotSize: Math.round(10 * previewPill.previewScale)
                            Layout.preferredWidth: dotSize
                            Layout.preferredHeight: dotSize
                            radius: dotSize / 2
                            color: /^#[0-9a-fA-F]{6}$/.test(accentField.text) ? accentField.text : "#8b5cf6"
                        }
                        QC.Label {
                            text: i18n("Playing")
                            color: previewBackdrop.fgColor
                            font.pixelSize: Math.round(11 * previewPill.previewScale)
                        }
                    }
                }
            }
        }

        // ── 3. Quick Presets (4 Diverse Themes for Current Color Mode) ──
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("🎨  Quick Presets")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Theme")
            spacing: 8

            Repeater {
                model: page.cfg_themeMode === "light"
                       ? [
                             { label: i18n("Cloud"), bg: "#f4f4f5", accent: "#7c3aed" },
                             { label: i18n("Snow"),  bg: "#ffffff", accent: "#2563eb" },
                             { label: i18n("Sky"),   bg: "#e0f2fe", accent: "#0284c7" },
                             { label: i18n("Sand"),  bg: "#faf3e8", accent: "#d97706" }
                         ]
                       : [
                             { label: i18n("Charcoal"), bg: "#1e1f22", accent: "#8b5cf6" },
                             { label: i18n("Obsidian"), bg: "#0b0d12", accent: "#3b82f6" },
                             { label: i18n("Ocean"),    bg: "#0f172a", accent: "#06b6d4" },
                             { label: i18n("Emerald"),  bg: "#0f1a14", accent: "#22c55e" }
                         ]

                Rectangle {
                    id: presetBtn
                    required property var modelData
                    readonly property bool selected: bgField.text.toLowerCase() === modelData.bg
                                                     && accentField.text.toLowerCase() === modelData.accent

                    Layout.preferredWidth: 76; Layout.preferredHeight: 28; radius: 14
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
                            color:  presetBtn.modelData.bg
                            border.width: 1
                            border.color: Qt.rgba(128/255, 128/255, 128/255, 0.5)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width:  5; height: 5; radius: 2.5
                            color:  presetBtn.modelData.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        QC.Label {
                            text:           presetBtn.modelData.label
                            font.pixelSize: 11
                            font.weight:    presetBtn.selected ? Font.Bold : Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: themeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            bgField.text     = presetBtn.modelData.bg
                            accentField.text = presetBtn.modelData.accent
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
