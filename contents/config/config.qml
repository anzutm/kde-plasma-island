import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name:   i18n("Clock & Weather")
        icon:   "configure"
        source: "ConfigGeneral.qml"
    }
    ConfigCategory {
        name:   i18n("Appearance")
        icon:   "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
    ConfigCategory {
        name:   i18n("Modules")
        icon:   "view-grid"
        source: "ConfigModules.qml"
    }
}
