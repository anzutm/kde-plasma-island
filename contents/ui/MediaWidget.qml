// MediaWidget.qml — Plasma Island for KDE Plasma 6
// Layout: [Album Art] [Title / Artist Marquee] [⏮] [▶/⏸] [⏭] [Mirrored Bass Waveform]
// Waveform: Real-time 7-band PipeWire FFT soundwave with smooth quadratic spline interpolation
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

    // Real-time PipeWire FFT bass analyzer state (with automatic fallback)
    readonly property string bassScriptPath: Qt.resolvedUrl("../scripts/audio_bass.py").toString().replace(/^file:\/\//, "")
    property int  bassPort:        0
    property bool _bassStarting:   false
    property bool _bassInFlight:   false
    property var  fftBands:        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    property bool hasLiveAudio:    false
    property real _lastLiveMs:     0

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

            if (source.includes("bass_start_")) {
                root._bassStarting = false
                const m = out.match(/PORT:(\d+)/)
                if (m && root.playing && root.shouldShow) {
                    root.bassPort = parseInt(m[1]) || 0
                }
            } else if (source.includes("playerctl_sync_")) {
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

    function startBassAnalyzer() {
        if (root.bassPort > 0 || root._bassStarting) return
        root._bassStarting = true
        const safePath = root.bassScriptPath.replace(/'/g, "'\\''")
        mediaExec.connectSource(
            `bash -c 'python3 '\''${safePath}'\'' --ppid $(ps -o ppid= -p $$ | tr -d " ")'  # bass_start_${Date.now()}`
        )
    }

    function stopBassAnalyzer() {
        root._bassStarting = false
        root._bassInFlight = false
        root.hasLiveAudio = false
        root.fftBands = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        if (root.bassPort > 0) {
            const url = `http://127.0.0.1:${root.bassPort}/stop`
            root.bassPort = 0
            const xhr = new XMLHttpRequest()
            xhr.timeout = 300
            xhr.open("GET", url)
            xhr.send()
        }
    }

    function pollBassAnalyzer() {
        if (root.bassPort <= 0 || root._bassInFlight) return
        root._bassInFlight = true
        const xhr = new XMLHttpRequest()
        xhr.timeout = 250
        xhr.ontimeout = function() { root._bassInFlight = false }
        xhr.onerror = function() {
            root._bassInFlight = false
            root.bassPort = 0
            root.hasLiveAudio = false
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root._bassInFlight = false
            if (xhr.status === 200) {
                try {
                    const d = JSON.parse(xhr.responseText)
                    const arr = Array.isArray(d.bands) && d.bands.length >= 7
                                ? d.bands.map(v => Math.max(0, Math.min(1, Number(v) || 0)))
                                : [0, 0, 0, 0, 0, 0, 0]
                    const maxBand = Math.max.apply(null, arr)
                    const now = Date.now()
                    if (maxBand > 0.015) {
                        root._lastLiveMs = now
                        root.hasLiveAudio = true
                    } else if (now - root._lastLiveMs > 1500) {
                        root.hasLiveAudio = false
                    }
                    root.fftBands = arr
                    waveCanvas.requestPaint()
                } catch(e) {}
            }
        }
        xhr.open("GET", `http://127.0.0.1:${root.bassPort}/bass`)
        xhr.send()
    }

    readonly property bool waveActive: root.playing && root.shouldShow
    onWaveActiveChanged: {
        if (waveActive) startBassAnalyzer()
        else stopBassAnalyzer()
    }
    Component.onDestruction: stopBassAnalyzer()

    Timer {
        id: bassPollTimer
        interval: 33
        running:  root.waveActive && root.bassPort > 0
        repeat:   true
        onTriggered: root.pollBassAnalyzer()
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
            if (root.waveActive && root.bassPort === 0 && !root._bassStarting) {
                root.startBassAnalyzer()
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
                isMask:           true
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
                    duration: 1800
                    loops:    Animation.Infinite
                    running:  root.waveActive && !root.hasLiveAudio
                }

                onPaint: {
                    const ctx = getContext("2d")
                    const w = width
                    const h = height
                    ctx.clearRect(0, 0, w, h)
                    if (w <= 0 || h <= 0) return

                    const cy = h * 0.5
                    const maxHalf = h * 0.48
                    const bands = root.fftBands
                    const live = root.hasLiveAudio

                    // Build 7 FFT magnitudes (b0 = sub-bass left, b6 = highs right)
                    const b = new Array(7)
                    for (let i = 0; i < 7; i++) {
                        if (!root.playing) {
                            b[i] = 0.55
                        } else if (live) {
                            b[i] = Math.max(0.05, Math.min(1.0, bands[i] || 0))
                        } else {
                            const kick = Math.pow(0.5 + 0.5 * Math.sin(phase * 2 - i * 0.45), 2.0)
                            b[i] = 0.14 + 0.78 * kick * (1.0 - i * 0.08)
                        }
                    }

                    // Left-to-right FFT spectrum with matching sleek horizontal needle tails on both ends
                    const pts = [
                        { x: 0.00, y: 0.0 },
                        { x: 0.03, y: 0.055 + b[0] * 0.05 },
                        { x: 0.08, y: 0.065 + b[0] * 0.12 },
                        { x: 0.14, y: b[0] * 0.62 },
                        { x: 0.22, y: b[0] * 1.44 },
                        { x: 0.30, y: Math.min(b[0], b[1]) * 0.28 },
                        { x: 0.38, y: b[1] * 1.34 },
                        { x: 0.46, y: Math.min(b[1], b[2]) * 0.26 },
                        { x: 0.54, y: b[2] * 1.24 },
                        { x: 0.62, y: Math.min(b[2], b[3]) * 0.24 },
                        { x: 0.69, y: b[3] * 1.24 },
                        { x: 0.76, y: Math.min(b[3], b[4]) * 0.24 },
                        { x: 0.83, y: b[4] * 1.18 },
                        { x: 0.89, y: Math.min(b[4], b[5]) * 0.22 },
                        { x: 0.93, y: b[5] * 1.05 },
                        { x: 0.96, y: 0.065 + b[6] * 0.45 },
                        { x: 0.985, y: 0.055 + b[6] * 0.08 },
                        { x: 1.00, y: 0.0 }
                    ]

                    // Convert to pixel coordinates (quadratic spline apex reaches ~0.5*ctrl + 0.5*valley)
                    const topX = new Array(pts.length)
                    const topY = new Array(pts.length)
                    const botY = new Array(pts.length)
                    for (let i = 0; i < pts.length; i++) {
                        const taper = Math.sin(Math.PI * pts[i].x)
                        const hh = maxHalf * amp * Math.min(1.65, pts[i].y + (root.playing ? 0.04 * taper : 0))
                        topX[i] = pts[i].x * w
                        topY[i] = cy - hh
                        botY[i] = cy + hh
                    }

                    // Smooth quadratic spline across top contour then mirrored bottom contour
                    ctx.beginPath()
                    ctx.moveTo(topX[0], cy)
                    for (let i = 1; i < pts.length - 1; i++) {
                        const mx = (topX[i] + topX[i + 1]) * 0.5
                        const my = (topY[i] + topY[i + 1]) * 0.5
                        ctx.quadraticCurveTo(topX[i], topY[i], mx, my)
                    }
                    ctx.lineTo(topX[pts.length - 1], cy)

                    for (let i = pts.length - 2; i >= 1; i--) {
                        const mx = (topX[i] + topX[i - 1]) * 0.5
                        const my = (botY[i] + botY[i - 1]) * 0.5
                        ctx.quadraticCurveTo(topX[i], botY[i], mx, my)
                    }
                    ctx.lineTo(topX[0], cy)
                    ctx.closePath()
                    ctx.fillStyle = waveColor
                    ctx.fill()
                }
            }
        }
    }
}
