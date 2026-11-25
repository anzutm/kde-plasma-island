// StatusWidget.qml — Plasma Island for KDE Plasma 6
// Optimized: Single unified atomic bash telemetry (1 fork vs 6), coretemp/k10temp priority, non-scanning WiFi, tabular numbers
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support

Item {
    id: root

    readonly property bool showWidget: plasmoid.configuration.showStatusWidget
    readonly property bool showGroup1: plasmoid.configuration.statusShowNetwork || plasmoid.configuration.statusShowBluetooth
    readonly property bool showGroup2: (plasmoid.configuration.statusShowBattery && batteryPercent >= 0)
                                       || (plasmoid.configuration.statusShowVolume && volumePercent >= 0)
    readonly property bool showGroup3: plasmoid.configuration.statusShowNetSpeed || plasmoid.configuration.statusShowCpu
                                       || plasmoid.configuration.statusShowTemp || plasmoid.configuration.statusShowRam
    readonly property bool hasAnyModule: showWidget && (showGroup1 || showGroup2 || showGroup3 || plasmoid.configuration.statusShowActions)

    visible:        hasAnyModule
    implicitWidth:  hasAnyModule ? mainRow.implicitWidth + 20 : 0
    implicitHeight: 34

    // ── State ─────────────────────────────────────────────────────
    property string wifiSsid:        ""
    property bool   wifiConnected:   false
    property bool   bluetoothOn:     false
    property string bluetoothDevice: ""
    property int    batteryPercent:  -1
    property bool   batteryCharging: false
    property int    volumePercent:   -1
    property bool   volumeMuted:     false
    property string netSpeed:        "0 KB/s"
    property int    cpuPercent:      0
    property string cpuTemp:         "--"
    property int    ramPercent:      0

    readonly property bool isLight: plasmoid.configuration.themeMode === "light"
    readonly property string accent: /^#[0-9a-fA-F]{6}$/.test(plasmoid.configuration.accentColor)
                                     ? plasmoid.configuration.accentColor : "#8b5cf6"

    function tempColor(t) {
        const v = parseInt(t)
        if (isNaN(v)) return root.isLight ? "#18181b" : "white"
        if (v >= 85)  return root.isLight ? "#dc2626" : "#ef4444"
        if (v >= 70)  return root.isLight ? "#ea580c" : "#f97316"
        if (v >= 55)  return root.isLight ? "#ca8a04" : "#eab308"
        return root.isLight ? "#16a34a" : "#4ade80"
    }
    function usageColor(p, hi, mid) {
        if (p >= hi)  return root.isLight ? "#dc2626" : "#ef4444"
        if (p >= mid) return root.isLight ? "#ca8a04" : "#eab308"
        return root.isLight ? "#18181b" : "white"
    }
    function formatSpeed(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024)    return Math.round(bps / 1024) + " KB/s"
        if (bps > 0)        return (bps / 1024).toFixed(1) + " KB/s"
        return "0 KB/s"
    }

    // ── Single Unified Polling Engine (1 process fork per tick) ───
    // Tracked Plasma 6 compatibility dependency (plasma5support executable engine)
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []

        property real   _prevIdle:  0
        property real   _prevTotal: 0
        property real   _prevRx:    0
        property real   _prevTime:  0

        onNewData: function(source, data) {
            const out = (data["stdout"] || "").trim()

            if (source.includes("island_all")) {
                const parts = out.split('|||')
                if (parts.length >= 9) {
                    // 0: CPU idle total
                    const cpuParts = parts[0].trim().split(/\s+/)
                    if (cpuParts.length >= 2) {
                        const idle  = parseFloat(cpuParts[0]) || 0
                        const total = parseFloat(cpuParts[1]) || 0
                        const dI = idle  - exec._prevIdle
                        const dT = total - exec._prevTotal
                        if (dT > 0 && exec._prevTotal > 0) {
                            root.cpuPercent = Math.min(100, Math.max(0, Math.round((1 - dI/dT) * 100)))
                        }
                        exec._prevIdle  = idle
                        exec._prevTotal = total
                    }

                    // 1: RAM %
                    const ram = parseInt(parts[1])
                    if (!isNaN(ram)) root.ramPercent = ram

                    // 2: Temp °C
                    const temp = parts[2].trim()
                    root.cpuTemp = (temp !== "" && temp !== "0") ? temp : "--"

                    // 3: Net RX
                    const netParts = parts[3].trim().split(/\s+/)
                    if (netParts.length >= 1 && netParts[0] !== "") {
                        const rx  = parseFloat(netParts[0]) || 0
                        const now = Date.now() / 1000
                        const dt  = now - exec._prevTime
                        if (exec._prevTime > 0 && dt > 0) {
                            const dRx = (rx >= exec._prevRx) ? (rx - exec._prevRx) : 0
                            root.netSpeed = root.formatSpeed(dRx / dt)
                        }
                        exec._prevRx   = rx
                        exec._prevTime = now
                    }

                    // 4: Wi-Fi SSID
                    if (plasmoid.configuration.statusShowNetwork) {
                        const ssid = parts[4].trim()
                        root.wifiSsid      = ssid
                        root.wifiConnected = (ssid !== "")
                    }

                    // 5: Bluetooth
                    if (plasmoid.configuration.statusShowBluetooth) {
                        root.bluetoothOn = (parts[5].trim() === "1")
                    }

                    // 6: Volume
                    if (plasmoid.configuration.statusShowVolume) {
                        const vOut = parts[6]
                        root.volumeMuted = vOut.includes("[MUTED]")
                        const m = vOut.match(/Volume:\s*([\d.]+)/)
                        if (m) root.volumePercent = Math.round(parseFloat(m[1]) * 100)
                    }

                    // 7 & 8: Battery
                    if (plasmoid.configuration.statusShowBattery) {
                        const pct = parseInt(parts[7])
                        root.batteryPercent = isNaN(pct) ? -1 : pct
                        root.batteryCharging = parts[8].toLowerCase().includes("charging")
                    }
                }
            }

            disconnectSource(source)
        }
    }

    function buildPollCmd() {
        const c = plasmoid.configuration
        // Coerce config booleans strictly to 0/1 integers before shell interpolation
        const toFlag       = (v) => (v === true ? 1 : 0)
        const needCpu      = toFlag(c.statusShowCpu)
        const needRam      = toFlag(c.statusShowRam)
        const needTemp     = toFlag(c.statusShowTemp)
        const needNetSpeed = toFlag(c.statusShowNetSpeed)
        const needProc     = (needCpu || needRam || needNetSpeed) ? 1 : 0
        const needNet      = toFlag(c.statusShowNetwork)
        const needBt       = toFlag(c.statusShowBluetooth)
        const needVol      = toFlag(c.statusShowVolume)
        const needBat      = toFlag(c.statusShowBattery)

        return `bash -c '` +
            `c=""; r=""; t=""; n=""; w=""; b=""; v=""; bc=""; bs=""; ` +
            `if [ ${needProc} -eq 1 ]; then ` +
            `  hw=$(awk -v nr=${needRam} -v nc=${needCpu} -v nn=${needNetSpeed} "` +
            `FILENAME==\\"/proc/meminfo\\" && nr { if (/^MemAvailable:/) a=\\$2; else if (/^MemTotal:/) t=\\$2 } ` +
            `FILENAME==\\"/proc/stat\\" && nc && /^cpu / { tot=0; for(i=2;i<=NF;i++) tot+=\\$i; ci=\\$5+\\$6; ct=tot } ` +
            `FILENAME==\\"/proc/net/dev\\" && nn && /^ *(eth|en|wl|wlan|eno|ens|wlp)/ { rx+=\\$2 } ` +
            `END { rp=(nr&&t>0)?sprintf(\\"%d\\",(1-a/t)*100):\\"\\"; cp=(nc&&ct>0)?(ci \\" \\" ct):\\"\\"; np=nn?sprintf(\\"%.0f\\",rx+0):\\"\\"; printf \\"%s@%s@%s\\",cp,rp,np }" /proc/meminfo /proc/stat /proc/net/dev); ` +
            `  c=\${hw%%@*}; rest=\${hw#*@}; r=\${rest%%@*}; n=\${rest#*@}; ` +
            `fi; ` +
            `if [ ${needTemp} -eq 1 ]; then ` +
            `  for d in /sys/class/hwmon/hwmon*; do read -r nm < "$d/name" 2>/dev/null || continue; if [ "$nm" = "coretemp" ] || [ "$nm" = "k10temp" ] || [ "$nm" = "zenpower" ]; then read -r t < "$d/temp1_input" 2>/dev/null; break; fi; done; ` +
            `  if [ -z "$t" ]; then for f in /sys/class/thermal/thermal_zone0/temp /sys/class/hwmon/hwmon*/temp1_input; do read -r t < "$f" 2>/dev/null && [ -n "$t" ] && break; done; fi; ` +
            `  t=$(( \${t:-0} / 1000 )); ` +
            `fi; ` +
            `[ ${needNet} -eq 1 ] && w=$(timeout 1.5 nmcli -t -f active,ssid dev wifi list --rescan no 2>/dev/null | awk -F: "/^yes:/{sub(/^yes:/,\\"\\"); print; exit}"); ` +
            `if [ ${needBt} -eq 1 ]; then b=0; for rf in /sys/class/rfkill/rfkill*; do if [ "$(cat "$rf/type" 2>/dev/null)" = "bluetooth" ] && [ "$(cat "$rf/state" 2>/dev/null)" = "1" ]; then p=$(timeout 0.4 busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered 2>/dev/null); case "$p" in *false*) b=0 ;; *) b=1 ;; esac; break; fi; done; fi; ` +
            `[ ${needVol} -eq 1 ] && v=$(timeout 1 wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); ` +
            `if [ ${needBat} -eq 1 ]; then for d in /sys/class/power_supply/BAT*; do [ -d "$d" ] || continue; read -r bc < "$d/capacity" 2>/dev/null; read -r bs < "$d/status" 2>/dev/null; break; done; fi; ` +
            `printf "%s|||%s|||%s|||%s|||%s|||%s|||%s|||%s|||%s\\n" "$c" "$r" "$t" "$n" "$w" "$b" "$v" "$bc" "$bs"' 2>/dev/null  # island_all`
    }

    function toggleBluetooth() {
        if (root.bluetoothOn) {
            exec.connectSource(`(timeout 3 bluetoothctl power off; rfkill block bluetooth) >/dev/null 2>&1 &  # bt_${Date.now()}`)
            root.bluetoothOn = false
        } else {
            exec.connectSource(`(rfkill unblock bluetooth; timeout 3 bluetoothctl power on) >/dev/null 2>&1 &  # bt_${Date.now()}`)
            root.bluetoothOn = true
        }
    }

    Timer {
        id: pollTimer
        interval:         Math.max(1, parseInt(plasmoid.configuration.statusRefreshInterval) || 3) * 1000
        running:          root.showWidget
        repeat:           true
        triggeredOnStart: true
        onTriggered:      exec.connectSource(root.buildPollCmd())
    }

    // ── Layout ────────────────────────────────────────────────────
    Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: 8

        // ─ Group 1: Connectivity (WiFi Capsule + Bluetooth Icon) ──
        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showGroup1

            // Wi-Fi Capsule (Icon + SSID with safe internal padding)
            Rectangle {
                id: wifiBadge
                visible:  plasmoid.configuration.statusShowNetwork
                height:   26
                width:    wifiInnerRow.implicitWidth + 24
                radius:   13
                color:    root.wifiConnected
                          ? (root.isLight ? "#18181b" : "#ffffff")
                          : (root.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.08))
                border.width: root.wifiConnected ? 0 : 1
                border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.16)

                Behavior on color { ColorAnimation { duration: 250 } }

                Row {
                    id: wifiInnerRow
                    anchors.centerIn: parent
                    spacing: 6

                    Kirigami.Icon {
                        source: root.wifiConnected
                                ? "network-wireless-connected-100-symbolic"
                                : "network-wireless-disconnected-symbolic"
                        implicitWidth:  14
                        implicitHeight: 14
                        anchors.verticalCenter: parent.verticalCenter
                        isMask: true
                        color: root.wifiConnected
                               ? (root.isLight ? "#ffffff" : "#1e1f22")
                               : (root.isLight ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.45))
                    }

                    PC3.Label {
                        text:           root.wifiConnected ? root.wifiSsid : i18n("No Wi-Fi")
                        font.pixelSize: 11
                        font.weight:    Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                        color:          root.wifiConnected
                                        ? (root.isLight ? "#ffffff" : "#1e1f22")
                                        : (root.isLight ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.5))
                        elide:          Text.ElideRight
                        maximumLineCount: 1
                        width:          Math.min(implicitWidth, 110)
                    }
                }

                MouseArea {
                    id: wifiArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    exec.connectSource(`kcmshell6 kcm_networkmanagement >/dev/null 2>&1 &  # net_${Date.now()}`)
                }

                PC3.ToolTip.visible: wifiArea.containsMouse
                PC3.ToolTip.text:    root.wifiConnected
                                     ? i18n("Wi-Fi: %1\nClick for settings", root.wifiSsid)
                                     : i18n("Wi-Fi Disconnected")
                PC3.ToolTip.delay:   600
            }

            // Bluetooth Badge (Icon ONLY)
            Rectangle {
                id: btBadge
                visible:  plasmoid.configuration.statusShowBluetooth
                height:   26
                width:    26
                radius:   13
                color:    root.bluetoothOn
                          ? (root.isLight ? "#18181b" : "#ffffff")
                          : (root.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.08))
                border.width: root.bluetoothOn ? 0 : 1
                border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.16)

                Behavior on color { ColorAnimation { duration: 250 } }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: root.bluetoothOn
                            ? "preferences-system-bluetooth-activated-symbolic"
                            : "network-bluetooth-symbolic"
                    implicitWidth:  14
                    implicitHeight: 14
                    isMask: true
                    color: root.bluetoothOn
                           ? (root.isLight ? "#ffffff" : "#1e1f22")
                           : (root.isLight ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.45))
                }

                Rectangle {
                    anchors.fill: parent
                    radius:       parent.radius
                    color:        root.isLight
                                  ? Qt.rgba(0, 0, 0, btArea.containsMouse ? 0.12 : 0)
                                  : Qt.rgba(1, 1, 1, btArea.containsMouse ? 0.15 : 0)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: btArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.toggleBluetooth()
                }

                PC3.ToolTip.visible: btArea.containsMouse
                PC3.ToolTip.text:    root.bluetoothOn
                                     ? i18n("Bluetooth: On\nClick to turn off")
                                     : i18n("Bluetooth: Off\nClick to turn on")
                PC3.ToolTip.delay:   600
            }
        }

        // ─ Divider 1 ─────────────────────────────────────────────
        Rectangle {
            width: 1; height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: root.isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.12)
            visible: root.showGroup1 && root.showGroup2
        }

        // ─ Group 2: System (Battery + Volume) ────────────────────
        Row {
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showGroup2

            // Battery (auto-hides on PC/desktop)
            Item {
                width:  batRow.implicitWidth
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                visible: plasmoid.configuration.statusShowBattery && root.batteryPercent >= 0

                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 4

                    Kirigami.Icon {
                        source: root.batteryCharging
                                ? "battery-charging-symbolic"
                                : (root.batteryPercent < 10 ? "battery-000-symbolic"
                                   : (root.batteryPercent < 30 ? "battery-020-symbolic"
                                      : (root.batteryPercent < 55 ? "battery-040-symbolic"
                                         : (root.batteryPercent < 75 ? "battery-060-symbolic"
                                            : (root.batteryPercent < 90 ? "battery-080-symbolic" : "battery-100-symbolic")))))
                        implicitWidth:  14
                        implicitHeight: 14
                        anchors.verticalCenter: parent.verticalCenter
                        isMask: true
                        color: root.batteryPercent < 20
                               ? (root.isLight ? "#dc2626" : "#ef4444")
                               : (root.isLight ? "#18181b" : "white")
                    }

                    PC3.Label {
                        text:           root.batteryPercent + "%"
                        font.pixelSize: 11
                        font.weight:    Font.Medium
                        font.features:  { "tnum": 1 }
                        anchors.verticalCenter: parent.verticalCenter
                        color:          root.batteryPercent < 20
                                        ? (root.isLight ? "#dc2626" : "#ef4444")
                                        : (root.isLight ? "#18181b" : "white")
                    }
                }

                MouseArea {
                    id: batArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                PC3.ToolTip.visible: batArea.containsMouse
                PC3.ToolTip.text:    i18n("Battery: %1% (%2)", root.batteryPercent, root.batteryCharging ? i18n("Charging") : i18n("Discharging"))
                PC3.ToolTip.delay:   600
            }

            // Volume (Click to mute, scroll wheel to adjust)
            Item {
                width:  volRow.implicitWidth
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                visible: plasmoid.configuration.statusShowVolume && root.volumePercent >= 0

                Row {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 4

                    Kirigami.Icon {
                        source: (root.volumeMuted || root.volumePercent === 0)
                                ? "audio-volume-muted-symbolic"
                                : (root.volumePercent < 35 ? "audio-volume-low-symbolic"
                                   : (root.volumePercent < 70 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"))
                        implicitWidth:  14
                        implicitHeight: 14
                        anchors.verticalCenter: parent.verticalCenter
                        isMask: true
                        color: root.volumeMuted
                               ? (root.isLight ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.45))
                               : (root.isLight ? "#18181b" : "white")
                    }

                    PC3.Label {
                        text:           root.volumeMuted ? i18n("Muted") : (root.volumePercent + "%")
                        font.pixelSize: 11
                        font.weight:    Font.Medium
                        font.features:  { "tnum": 1 }
                        anchors.verticalCenter: parent.verticalCenter
                        color:          root.volumeMuted
                                        ? (root.isLight ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.45))
                                        : (root.isLight ? "#18181b" : "white")
                    }
                }

                MouseArea {
                    id: volArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onWheel: function(wheel) {
                        wheel.accepted = true
                        if (wheel.angleDelta.y > 0) {
                            exec.connectSource(`wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ >/dev/null 2>&1 &  # vol_${Date.now()}`)
                            root.volumePercent = Math.min(100, root.volumePercent + 5)
                            root.volumeMuted = false
                        } else if (wheel.angleDelta.y < 0) {
                            exec.connectSource(`wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- >/dev/null 2>&1 &  # vol_${Date.now()}`)
                            root.volumePercent = Math.max(0, root.volumePercent - 5)
                        }
                    }
                    onClicked: {
                        exec.connectSource(`wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1 &  # mute_${Date.now()}`)
                        root.volumeMuted = !root.volumeMuted
                    }
                }

                PC3.ToolTip.visible: volArea.containsMouse
                PC3.ToolTip.text:    root.volumeMuted
                                     ? i18n("Volume: Muted\nClick to unmute, scroll to adjust")
                                     : i18n("Volume: %1%\nClick to mute, scroll to adjust", root.volumePercent)
                PC3.ToolTip.delay:   600
            }
        }

        // ─ Divider 2 ─────────────────────────────────────────────
        Rectangle {
            width: 1; height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: root.isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.12)
            visible: (root.showGroup1 || root.showGroup2) && root.showGroup3
        }

        // ─ Group 3: Hardware Monitor ──────────────────────────────
        Row {
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showGroup3

            // Net Speed (Download Throughput)
            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                visible: plasmoid.configuration.statusShowNetSpeed

                PC3.Label {
                    text:           "↓"
                    font.pixelSize: 12
                    font.weight:    Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                    color:          root.isLight ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(1, 1, 1, 0.6)
                }

                PC3.Label {
                    width:          Math.max(54, implicitWidth)
                    text:           root.netSpeed
                    font.pixelSize: 11
                    font.weight:    Font.Medium
                    font.features:  { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                    color:          root.isLight ? "#18181b" : "white"
                }
            }

            // CPU
            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                visible: plasmoid.configuration.statusShowCpu

                PC3.Label {
                    text: i18n("CPU")
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isLight ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.45)
                }
                PC3.Label {
                    width:               Math.max(28, implicitWidth)
                    horizontalAlignment: Text.AlignRight
                    text:                root.cpuPercent + "%"
                    font.pixelSize:      11
                    font.weight:         Font.Bold
                    font.features:       { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                    color:               root.usageColor(root.cpuPercent, 90, 70)
                }
            }

            // Temp
            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                visible: plasmoid.configuration.statusShowTemp

                Kirigami.Icon {
                    source: (parseInt(root.cpuTemp) >= 70) ? "temperature-warm-symbolic" : "temperature-normal-symbolic"
                    implicitWidth:  13
                    implicitHeight: 13
                    anchors.verticalCenter: parent.verticalCenter
                    isMask: true
                    color: root.isLight ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(1, 1, 1, 0.55)
                }
                PC3.Label {
                    width:               Math.max(22, implicitWidth)
                    horizontalAlignment: Text.AlignRight
                    text:                root.cpuTemp !== "--" ? root.cpuTemp + "°" : "--"
                    font.pixelSize:      11
                    font.weight:         Font.Bold
                    font.features:       { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                    color:               root.tempColor(root.cpuTemp)
                }
            }

            // RAM
            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                visible: plasmoid.configuration.statusShowRam

                PC3.Label {
                    text: i18n("RAM")
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isLight ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.45)
                }
                PC3.Label {
                    width:               Math.max(28, implicitWidth)
                    horizontalAlignment: Text.AlignRight
                    text:                root.ramPercent + "%"
                    font.pixelSize:      11
                    font.weight:         Font.Bold
                    font.features:       { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                    color:               root.usageColor(root.ramPercent, 90, 75)
                }
            }
        }

        // ─ Divider 3 ─────────────────────────────────────────────
        Rectangle {
            width: 1; height: 18
            anchors.verticalCenter: parent.verticalCenter
            color: root.isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.12)
            visible: plasmoid.configuration.statusShowActions
                     && (root.showGroup1 || root.showGroup2 || root.showGroup3)
        }

        // ─ Group 4: Quick Actions ─────────────────────────────────
        Row {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter
            visible: plasmoid.configuration.statusShowActions

            Repeater {
                model: [
                    { icon: "configure-symbolic", tooltip: i18n("System Settings"), cmd: "systemsettings >/dev/null 2>&1 &" },
                    { icon: "edit-find-symbolic", tooltip: i18n("KRunner Search"),  cmd: "krunner >/dev/null 2>&1 &"        }
                ]

                Rectangle {
                    width:  26; height: 26; radius: 13
                    color:  actionArea.containsMouse
                            ? (root.isLight ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.18))
                            : (root.isLight ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.08))
                    border.width: 1
                    border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.1)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: modelData.icon
                        implicitWidth:  13
                        implicitHeight: 13
                        isMask: true
                        color: root.isLight ? "#18181b" : "white"
                    }

                    PC3.ToolTip.visible: actionArea.containsMouse
                    PC3.ToolTip.text:    modelData.tooltip
                    PC3.ToolTip.delay:   600

                    MouseArea {
                        id:           actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    exec.connectSource(`${modelData.cmd}  # act_${Date.now()}`)
                    }
                }
            }
        }
    }
}
