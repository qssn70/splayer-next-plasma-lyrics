import QtQuick
import QtWebSockets
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "Lyrics.js" as Lyrics

// SPlayer-Next's public API is the only lyrics source. No LRCLIB or MPRIS lookups.
PlasmoidItem {
    id: root

    readonly property int apiPort: plasmoid.configuration.apiPort
    readonly property bool useWebSocket: plasmoid.configuration.useWebSocket
    readonly property string lyricMode: plasmoid.configuration.lyricMode
    readonly property bool showRomanInPopup: plasmoid.configuration.showRomanInPopup
    readonly property int fontSize: plasmoid.configuration.fontSize
    readonly property string fontFamily: plasmoid.configuration.fontFamily
    readonly property bool fontBold: plasmoid.configuration.fontBold
    readonly property bool fontItalic: plasmoid.configuration.fontItalic
    readonly property bool useCustomColor: plasmoid.configuration.useCustomColor
    readonly property string fontColor: plasmoid.configuration.fontColor
    readonly property string animationType: plasmoid.configuration.animationType
    readonly property int animationDuration: plasmoid.configuration.animationDuration
    readonly property int maxWidth: plasmoid.configuration.maxWidth
    readonly property int minWidth: plasmoid.configuration.minWidth
    readonly property string idleText: plasmoid.configuration.idleText

    property bool initialized: false
    property bool apiConnected: false
    property bool wsConnected: false
    property string trackId: ""
    property string songTitle: ""
    property string songArtist: ""
    property string coverUrl: ""
    property var lyricLines: []
    property int currentLineIndex: -1
    property real currentTimeMs: 0
    property real durationMs: 0
    property real lyricOffsetMs: 0
    property real speed: 1.0
    property bool isPlaying: false
    property real anchorPosition: 0
    property double anchorAt: 0
    property bool stateRequestPending: false
    property double stateRequestStarted: 0
    property int stateRequestSerial: 0
    property int lyricRequestSerial: 0
    property bool lyricRequestPending: false
    property double lyricRequestStarted: 0
    property double lastLyricAttempt: 0
    property int apiGeneration: 0
    property bool wsReconnectSuspended: false

    readonly property string currentLyric: currentLineIndex >= 0
        ? Lyrics.displayText(lyricLines[currentLineIndex], lyricMode) : ""
    readonly property string karaokeMarkup: currentLineIndex >= 0
        ? Lyrics.karaokeMarkup(lyricLines[currentLineIndex],
            currentTimeMs + lyricOffsetMs, lyricMode,
            String(Kirigami.Theme.highlightColor),
            String(useCustomColor ? fontColor : Kirigami.Theme.textColor)) : ""

    // Hide the actual Plasma applet, not just its disconnected warning text.
    // The HTTP poll timers remain active so it reappears when the API recovers.
    Plasmoid.status: root.apiConnected
        ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus

    preferredRepresentation: compactRepresentation

    compactRepresentation: CompactRepresentation {
        currentLyric: root.currentLyric
        karaokeMarkup: root.karaokeMarkup
        isPlaying: root.isPlaying
        apiConnected: root.apiConnected
        idleText: root.idleText
        fontSize: root.fontSize
        fontFamily: root.fontFamily
        fontBold: root.fontBold
        fontItalic: root.fontItalic
        useCustomColor: root.useCustomColor
        fontColor: root.fontColor
        animationType: root.animationType
        animationDuration: root.animationDuration
        minWidth: root.minWidth
        maxWidth: root.maxWidth
        songTitle: root.songTitle
        songArtist: root.songArtist
        onTogglePlayback: root.sendControl("toggle", 0)
        onExpandRequested: root.expanded = !root.expanded
    }

    fullRepresentation: FullRepresentation {
        currentLyric: root.currentLyric
        isPlaying: root.isPlaying
        apiConnected: root.apiConnected
        songTitle: root.songTitle
        songArtist: root.songArtist
        coverUrl: root.coverUrl
        currentTimeMs: root.currentTimeMs
        durationMs: root.durationMs
        lyricLines: root.lyricLines
        currentLineIndex: root.currentLineIndex
        showRomanization: root.showRomanInPopup
        onControlCommand: function(cmd, positionMs) { root.sendControl(cmd, positionMs) }
    }

    function numeric(value, fallback) {
        var n = Number(value)
        return isFinite(n) ? n : fallback
    }

    // Complete each request once. QML's XMLHttpRequest works directly from a plasmoid.
    // Using only the loopback host prevents remote hosts from receiving song metadata.
    function httpJson(method, path, payload, callback) {
        var request = new XMLHttpRequest()
        var complete = false
        function finish(ok, response) {
            if (complete) return
            complete = true
            callback(ok, response)
        }
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return
            if (request.status < 200 || request.status >= 300) {
                finish(false, null)
                return
            }
            try { finish(true, JSON.parse(request.responseText)) }
            catch (error) { finish(false, null) }
        }
        request.onerror = function() { finish(false, null) }
        try {
            request.open(method, "http://127.0.0.1:" + apiPort + path, true)
            if (method !== "GET") request.setRequestHeader("Content-Type", "application/json")
            request.send(method === "GET" ? null : JSON.stringify(payload || {}))
        } catch (error) {
            finish(false, null)
        }
    }

    function coverSource(cover) {
        if (typeof cover !== "string") return ""
        if (/^(https?:\/\/|file:\/\/)/i.test(cover)) return cover
        if (cover.charAt(0) === "/") return "file://" + cover
        return "" // private Electron protocols are not loadable by Plasma's QML Image
    }

    function clearTrack() {
        trackId = ""
        songTitle = ""
        songArtist = ""
        coverUrl = ""
        lyricLines = []
        currentLineIndex = -1
        currentTimeMs = 0
        durationMs = 0
        lyricOffsetMs = 0
        isPlaying = false
        lyricRequestSerial++
        lyricRequestPending = false
        lastLyricAttempt = 0
    }

    function applyTrack(track) {
        var nextId = track && track.id !== undefined && track.id !== null
            ? String(track.id) : ""
        var changed = nextId !== trackId
        if (changed) {
            trackId = nextId
            lyricLines = []
            currentLineIndex = -1
            lyricRequestSerial++
            lyricRequestPending = false
            lastLyricAttempt = 0
        }
        songTitle = track && typeof track.title === "string" ? track.title : ""
        if (track && Array.isArray(track.artists)) {
            songArtist = track.artists.map(function(artist) { return artist.name || "" })
                .filter(function(name) { return name.length > 0 }).join(", ")
        } else {
            songArtist = ""
        }
        coverUrl = track ? coverSource(track.cover) : ""
        durationMs = track ? Math.max(0, numeric(track.duration, 0)) : 0
        return changed
    }

    function setClock(position, playing, rate, timestamp) {
        var now = Date.now()
        isPlaying = !!playing
        speed = Math.max(0.5, Math.min(2.0, numeric(rate, 1)))
        var lag = now - numeric(timestamp, now)
        // Main process reports a timestamp valid at the start of the audio position.
        lag = Math.max(0, Math.min(lag, 5000))
        anchorPosition = Math.max(0, numeric(position, 0)) + (isPlaying ? lag * speed : 0)
        anchorAt = now
        advanceClock()
    }

    function advanceClock() {
        var elapsed = isPlaying ? Math.max(0, Date.now() - anchorAt) * speed : 0
        var next = anchorPosition + elapsed
        currentTimeMs = Math.max(0, durationMs > 0 ? Math.min(durationMs, next) : next)
        currentLineIndex = Lyrics.currentIndex(lyricLines, currentTimeMs + lyricOffsetMs)
    }

    function pollState(force) {
        if (stateRequestPending && Date.now() - stateRequestStarted < 3000) return
        stateRequestPending = true
        stateRequestStarted = Date.now()
        var serial = ++stateRequestSerial
        var generation = apiGeneration
        httpJson("GET", "/api/now-playing", null, function(ok, snapshot) {
            if (serial !== stateRequestSerial || generation !== apiGeneration) return
            stateRequestPending = false
            if (!ok || !snapshot || typeof snapshot !== "object") {
                apiConnected = false
                isPlaying = false
                return
            }
            apiConnected = true
            var changed = applyTrack(snapshot.track || null)
            lyricOffsetMs = numeric(snapshot.lyricOffsetMs, 0)
            setClock(snapshot.position, snapshot.playing, snapshot.speed, snapshot.sendTimestamp)
            if (!trackId) return
            if (snapshot.lyricAvailable === false && lyricLines.length > 0) {
                lyricLines = []
                currentLineIndex = -1
            }
            if ((changed || (snapshot.lyricAvailable && lyricLines.length === 0))
                    && Date.now() - lastLyricAttempt > 700) fetchLyrics()
        })
    }

    function fetchLyrics(force) {
        if (!trackId || !apiConnected) return
        if (lyricRequestPending && Date.now() - lyricRequestStarted < 3500) return
        if (!force && Date.now() - lastLyricAttempt < 700) return
        var wantedId = trackId
        var generation = apiGeneration
        var serial = ++lyricRequestSerial
        lastLyricAttempt = Date.now()
        lyricRequestPending = true
        lyricRequestStarted = Date.now()
        httpJson("GET", "/api/lyrics", null, function(ok, reply) {
            if (serial !== lyricRequestSerial || generation !== apiGeneration) return
            lyricRequestPending = false
            if (!ok || !reply || trackId !== wantedId) return
            // Guard against an old track's response arriving during a rapid switch.
            if (String(reply.trackId || "") !== wantedId) return
            var nextLines = Lyrics.normalizeLines(reply.lyric)
            lyricLines = nextLines
            lyricOffsetMs = numeric(reply.lyricOffsetMs, lyricOffsetMs)
            advanceClock()
        })
    }

    function onSocketMessage(message) {
        var event
        try { event = JSON.parse(message) } catch (error) { return }
        if (!event || event.kind !== "event") return
        switch (event.type) {
        case "track":
            // Track updates can precede the new lyric contents. Poll the REST snapshot.
            if (event.data && event.data.track) applyTrack(event.data.track)
            else applyTrack(null)
            pollState(true)
            break
        case "lyric":
            // WS data has no trackId, so confirm identity via /api/lyrics.
            pollState(true)
            fetchLyrics(true)
            break
        case "lyricOffset":
            if (event.data && String(event.data.trackId || "") === trackId) {
                lyricOffsetMs = numeric(event.data.offsetMs, lyricOffsetMs)
                advanceClock()
            }
            break
        case "state":
        case "loading":
        case "stopped":
        case "ended":
        case "transition":
            pollState(true)
            break
        }
    }

    function sendControl(command, positionMs) {
        if (!apiConnected) return
        var op = command === "toggle" ? (isPlaying ? "pause" : "play") : command
        if (["play", "pause", "prev", "next", "stop", "seek"].indexOf(op) === -1) return
        var payload = op === "seek" ? {positionMs: Math.max(0, Math.round(positionMs))} : {}
        httpJson("POST", "/api/" + op, payload, function(ok, response) {
            if (ok && response && response.ok) {
                if (op === "seek") setClock(payload.positionMs, isPlaying, speed, Date.now())
                else if (op === "play" || op === "pause") isPlaying = op === "play"
                resyncTimer.restart()
            }
        })
    }

    function resetConnection() {
        apiGeneration++
        stateRequestSerial++
        stateRequestPending = false
        apiConnected = false
        clearTrack()
        wsConnected = false
        wsReconnectSuspended = true
        reconnectTimer.restart()
        pollState(true)
    }

    onApiConnectedChanged: { if (!apiConnected) expanded = false }
    onApiPortChanged: { if (initialized) resetConnection() }
    onLyricModeChanged: { if (initialized) advanceClock() }
    Component.onCompleted: initialized = true

    Timer {
        id: bootstrapTimer
        interval: 200
        running: true
        repeat: false
        onTriggered: root.pollState(true)
    }
    Timer {
        id: stateTimer
        interval: 900
        repeat: true
        running: true
        onTriggered: root.pollState(false)
    }
    Timer {
        id: renderingTimer
        interval: 65
        repeat: true
        running: root.apiConnected && root.isPlaying
        onTriggered: root.advanceClock()
    }
    Timer {
        id: resyncTimer
        interval: 180
        repeat: false
        onTriggered: root.pollState(true)
    }
    Timer {
        // Covers lyric-source changes even with WebSocket disabled.
        id: lyricRefreshTimer
        interval: 12000
        repeat: true
        running: root.apiConnected
        onTriggered: root.fetchLyrics(true)
    }
    Timer {
        id: reconnectTimer
        interval: 3000
        repeat: false
        onTriggered: root.wsReconnectSuspended = false
    }
    WebSocket {
        id: ws
        url: "ws://127.0.0.1:" + root.apiPort + "/ws"
        active: root.useWebSocket && !root.wsReconnectSuspended
        onStatusChanged: {
            if (status === WebSocket.Open) {
                root.wsConnected = true
                root.pollState(true)
                root.fetchLyrics(true)
            } else if (status === WebSocket.Error || status === WebSocket.Closed) {
                root.wsConnected = false
                if (root.useWebSocket && !root.wsReconnectSuspended) {
                    root.wsReconnectSuspended = true
                    reconnectTimer.restart()
                }
            }
        }
        onTextMessageReceived: function(message) { root.onSocketMessage(message) }
    }
}
