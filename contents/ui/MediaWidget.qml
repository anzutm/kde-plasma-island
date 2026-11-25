// MediaWidget.qml — Plasma Island for KDE Plasma 6
// Layout: [Album Art] [Title / Artist Marquee] [⏮] [▶/⏸] [⏭] [Waveform Visualizer]
// Waveform: Modern 5-bar equalizer to the right of controls with fluid scene-graph animations
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support

Item {
    id: root

    readonly property bool   showWidget: plasmoid.configuration.showMediaWidget
    readonly property bool   autoHide:   plasmoid.configuration.mediaAutoHide
    readonly property bool   isLight:    plasmoid.configuration.themeMode === "light"
    readonly property string accent:     /^#[0-9a-fA-F]{6}$/.test(plasmoid.configuration.accentColor)
                                         ? plasmoid.configuration.accentColor : "#8b5cf6"

    property string artist:         ""
    property string title:          ""
    property string albumArt:       ""
    property string playbackStatus: "Stopped"
    property string activePlayer:   ""
    property bool   pendingControl: false
    property int    _syncSeq:       0

    readonly property bool playing:    playbackStatus === "Playing"
    readonly property bool hasMedia:   title !== "" && playbackStatus !== "Stopped"
    readonly property bool shouldShow: showWidget && (!autoHide || hasMedia)
    readonly property bool artReady:   albumArt !== "" && artImage.status === Image.Ready

    opacity:        shouldShow ? 1 : 0
    visible:        opacity > 0
    clip:           true
    implicitWidth:  shouldShow ? contentRow.implicitWidth + 20 : 0
    implicitHeight: 34

    Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on opacity       { NumberAnimation { duration: 250 } }

    function applyMetadata(out) {
        const lines = out ? out.split('\n') : []
        let best = null
        let bestScore = -1

        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split(':::')
            if (parts.length < 5) continue

            const player = (parts[0] || "").trim()
            const status = (parts[1] || "Stopped").trim()
            const artist = (parts[2] || "").trim()
            const title  = (parts[3] || "").trim()
            const artRaw = (parts[4] || "").trim()

            // Prefer Playing > Paused > Stopped, and Plasma Browser Integration / players with real metadata & artwork
            let score = 0
            if (status === "Playing") score += 100
            else if (status === "Paused") score += 50
            if (player.startsWith("plasma-browser-integration")) score += 20
            if (artist !== "") score += 10
            if (title !== "") score += 5
            if (artRaw !== "" && !artRaw.includes(".org.chromium.Chromium") && !artRaw.includes(".com.google.Chrome")) {
                score += 15
            } else if (artRaw !== "") {
                score += 2
            }

            if (score > bestScore) {
                bestScore = score
                best = { player, status, artist, title, artRaw }
            }
        }

        if (best) {
            root.activePlayer   = best.player
            root.playbackStatus = best.status || "Stopped"
            root.artist         = best.artist
            root.title          = best.title
            const art = best.artRaw
            root.albumArt = art.startsWith("file://") || art.startsWith("http://") || art.startsWith("https://")
                            ? art
                            : (art !== "" ? "file://" + art : "")
        } else {
            root.activePlayer   = ""
            root.playbackStatus = "Stopped"
            root.artist         = ""
            root.title          = ""
            root.albumArt       = ""
        }
    }

    // ── Single-line MPRIS command ─────────────────────────────────
    // Tracked Plasma 6 compatibility dependency (plasma5support executable engine)
    P5Support.DataSource {
        id: mediaExec
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            const out = (data["stdout"] || "").trim()

            if (source.includes("playerctl_sync_")) {
                if (source.includes(`playerctl_sync_${root._syncSeq}`)) {
                    root.pendingControl = false
                    root.applyMetadata(out)
                }
            } else if (source.includes("playerctl_metadata") && !root.pendingControl) {
                root.applyMetadata(out)
            }

            disconnectSource(source)
        }
    }

    function buildQueryCmd(tag) {
        return `bash -c 'out=$(timeout 1.5 playerctl -a metadata --format "{{playerName}}:::{{status}}:::{{artist}}:::{{title}}:::{{mpris:artUrl}}" 2>/dev/null); [ -n "$out" ] && printf "%s\\n" "$out" || echo ":::Stopped::::::"'  # ${tag}`
    }

    Timer {
        id: pollTimer
        interval:         1800
        running:          root.showWidget
        repeat:           true
        triggeredOnStart: true
        onTriggered: {
            if (!root.pendingControl) {
                mediaExec.connectSource(root.buildQueryCmd("playerctl_metadata"))
            }
        }
    }

    Timer {
        id: controlSyncTimer
        interval: 250
        running:  false
        repeat:   false
        onTriggered: {
            root._syncSeq += 1
            mediaExec.connectSource(root.buildQueryCmd("playerctl_sync_" + root._syncSeq))
        }
    }

    function sendControl(action) {
        if (!["previous", "play-pause", "next"].includes(action)) return
        root.pendingControl = true
        pollTimer.restart()
        const pFlag = /^[a-zA-Z0-9._-]+$/.test(root.activePlayer) ? `-p '${root.activePlayer}' ` : ""
        mediaExec.connectSource(`playerctl ${pFlag}${action} >/dev/null 2>&1 &  # ctrl_${Date.now()}`)
        controlSyncTimer.restart()
    }

    // ── Continuous Seamless Marquee ──────────────────────────────
    readonly property bool marqueeActive: titleText1.implicitWidth > titleClip.width
    readonly property real marqueeDistance: titleText1.implicitWidth + titleRow.spacing

    NumberAnimation {
        id: marqueeAnim
        target:   titleRow
        property: "x"
        from:     0
        to:       -root.marqueeDistance
        duration: Math.max(1000, root.marqueeDistance * 32)
        loops:    Animation.Infinite
        running:  root.marqueeActive && root.playing && root.shouldShow
        onRunningChanged: {
            if (!running) titleRow.x = 0;
        }
    }

    onTitleChanged: {
        titleRow.x = 0;
        if (marqueeAnim.running) marqueeAnim.restart();
    }

    // ── Layout ────────────────────────────────────────────────────
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 9

        // 1. Album Art (rounded with 8px corner radius mask)
        Rectangle {
            id: artBox
            width:  32; height: 32
            radius: 8
            color:  root.isLight ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(1, 1, 1, 0.08)
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: artImage
                anchors.fill:  parent
                source:        root.albumArt
                fillMode:      Image.PreserveAspectCrop
                visible:       false
                asynchronous:  true
                layer.enabled: root.artReady
            }

            Rectangle {
                id: artMask
                anchors.fill:  parent
                radius:        8
                visible:       false
                layer.enabled: root.artReady
            }

            MultiEffect {
                anchors.fill: parent
                source:       artImage
                maskEnabled:  root.artReady
                maskSource:   artMask
                visible:      root.artReady
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                source:           "music-note-16th-symbolic"
                implicitWidth:    16
                implicitHeight:   16
                color:            root.isLight ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.45)
                visible:          !root.artReady
            }

            // Subtle 1px inner border for depth
            Rectangle {
                anchors.fill: parent
                radius:       parent.radius
                color:        "transparent"
                border.width: 1
                border.color: root.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.12)
            }
        }

        // 2. Title + Artist (responsive width between 64 and 130 px)
        Column {
            spacing: 1
            width:   Math.min(Math.max(titleText1.contentWidth, artistLabel.contentWidth, 64), 130)
            anchors.verticalCenter: parent.verticalCenter

            Item {
                id:     titleClip
                width:  parent.width
                height: titleText1.implicitHeight
                clip:   true

                Row {
                    id:      titleRow
                    spacing: 28
                    x:       0

                    PC3.Label {
                        id:             titleText1
                        text:           root.title || i18n("No media")
                        font.pixelSize: 11
                        font.weight:    Font.DemiBold
                        color:          root.isLight ? "#18181b" : "white"
                    }

                    PC3.Label {
                        id:             titleText2
                        text:           titleText1.text
                        font.pixelSize: 11
                        font.weight:    Font.DemiBold
                        color:          root.isLight ? "#18181b" : "white"
                        visible:        root.marqueeActive
                    }
                }
            }

            PC3.Label {
                id:             artistLabel
                text:           root.artist || i18n("Music Player")
                font.pixelSize: 10
                color:          root.isLight ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.5)
                elide:          Text.ElideRight
                width:          parent.width
            }
        }

        // 3. Playback Controls (⏮ ▶/⏸ ⏭)
        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            // Previous
            Rectangle {
                width:  24; height: 24; radius: 12
                color:  prevHover.containsMouse
                        ? (root.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.16))
                        : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }

                PC3.Label {
                    anchors.centerIn: parent
                    text:             "⏮"
                    font.pixelSize:   10
                    color:            root.isLight ? Qt.rgba(0, 0, 0, 0.72) : Qt.rgba(1, 1, 1, 0.75)
                }
                MouseArea {
                    id: prevHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.sendControl("previous")
                }
            }

            // Play / Pause
            Rectangle {
                width:  26; height: 26; radius: 13
                color:  playHover.containsMouse
                        ? (root.isLight ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.22))
                        : (root.isLight ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.12))
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }

                PC3.Label {
                    anchors.centerIn: parent
                    text:             root.playing ? "⏸" : "▶"
                    font.pixelSize:   11
                    color:            root.isLight ? "#18181b" : "white"
                }
                MouseArea {
                    id: playHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.sendControl("play-pause")
                }
            }

            // Next
            Rectangle {
                width:  24; height: 24; radius: 12
                color:  nextHover.containsMouse
                        ? (root.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.16))
                        : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }

                PC3.Label {
                    anchors.centerIn: parent
                    text:             "⏭"
                    font.pixelSize:   10
                    color:            root.isLight ? Qt.rgba(0, 0, 0, 0.72) : Qt.rgba(1, 1, 1, 0.75)
                }
                MouseArea {
                    id: nextHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.sendControl("next")
                }
            }
        }

        // 4. Mirrored Continuous Soundwave Visualizer — placed to the RIGHT of Next button
        Item {
            id: waveBox
            width:   120
            height:  32
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: waveCanvas
                anchors.fill: parent
                antialiasing: true
                opacity:      root.playing ? 0.95 : 0.38

                property real phase: 0
                property real amp:   root.playing ? 1.0 : 0.12
                property color waveColor: root.accent

                Behavior on opacity { NumberAnimation { duration: 220 } }
                Behavior on amp     { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                onPhaseChanged:     requestPaint()
                onAmpChanged:       requestPaint()
                onWaveColorChanged: requestPaint()
                onAvailableChanged: if (available) requestPaint()

                NumberAnimation on phase {
                    from:     0
                    to:       Math.PI * 2
                    duration: 2200
                    loops:    Animation.Infinite
                    running:  root.playing && root.shouldShow
                }

                onPaint: {
                    const ctx = getContext("2d")
                    const w = width
                    const h = height
                    ctx.clearRect(0, 0, w, h)
                    if (w <= 0 || h <= 0) return

                    const cy = h * 0.5
                    const maxHalf = h * 0.48
                    const steps = 96

                    // 7 symmetrical mirrored lobes with smooth, calm harmonic motion
                    const lobes = [
                        { c: 0.11, w: 0.042, base: 0.38, s1: 1, s2: 2, off: 0.4 },
                        { c: 0.22, w: 0.044, base: 0.52, s1: 2, s2: 3, off: 1.7 },
                        { c: 0.35, w: 0.048, base: 0.46, s1: 1, s2: 3, off: 3.1 },
                        { c: 0.50, w: 0.066, base: 1.00, s1: 2, s2: 3, off: 0.0 },
                        { c: 0.65, w: 0.048, base: 0.46, s1: 1, s2: 3, off: 4.5 },
                        { c: 0.78, w: 0.044, base: 0.52, s1: 2, s2: 3, off: 2.4 },
                        { c: 0.89, w: 0.042, base: 0.38, s1: 1, s2: 2, off: 5.2 }
                    ]

                    const halfHeights = new Array(steps + 1)
                    for (let i = 0; i <= steps; i++) {
                        const u = i / steps
                        const endTaper = Math.sin(Math.PI * u)
                        // Continuous thin waist connecting the lobes
                        let env = 0.08 * Math.pow(endTaper, 1.3)

                        for (let k = 0; k < lobes.length; k++) {
                            const lb = lobes[k]
                            const d = (u - lb.c) / lb.w
                            const g = Math.exp(-d * d)
                            let mod = 1.0
                            if (root.playing) {
                                const h1 = Math.sin(phase * lb.s1 + lb.off)
                                const h2 = Math.cos(phase * lb.s2 - lb.off * 1.2)
                                const pulse = 0.62 + 0.24 * h1 + 0.16 * h2
                                mod = Math.max(0.35, Math.min(1.05, pulse))
                            }
                            env += lb.base * mod * g
                        }

                        if (root.playing) {
                            env += 0.03 * Math.sin(u * 14.0 - phase * 2.0) * Math.sin(Math.PI * u)
                        }

                        halfHeights[i] = maxHalf * amp * Math.max(0.0, Math.min(1.0, env)) * Math.pow(endTaper, 0.3)
                    }

                    ctx.beginPath()
                    ctx.moveTo(0, cy)
                    for (let i = 1; i <= steps; i++) {
                        ctx.lineTo((i / steps) * w, cy - halfHeights[i])
                    }
                    for (let i = steps - 1; i >= 0; i--) {
                        ctx.lineTo((i / steps) * w, cy + halfHeights[i])
                    }
                    ctx.closePath()
                    ctx.fillStyle = waveColor
                    ctx.fill()
                }
            }
        }
    }
}
