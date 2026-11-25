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

    Kirigami.FormLayout {

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
