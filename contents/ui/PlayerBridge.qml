import QtQuick
import QtWebSockets
import "Lyrics.js" as Lyrics
import "LxLyrics.js" as LxLyrics

// One independent bridge per player: requests, song IDs, lyrics, timers and
// WebSocket lifecycle must never be shared between the two players.
Item {
    id: root
    visible: false
    width: 0
    height: 0
    property string playerSource: "splayer"
    property bool bridgeEnabled: true
    property int apiPort: 14558
    property int lxApiPort: 23330
    readonly property int currentApiPort: playerSource === "lx" ? lxApiPort : apiPort
    property bool useWebSocket: true
    property string lyricMode: "original"
    property bool initialized: false
    property bool apiConnected: false
    property bool wsConnected: false
    property string trackId: ""
    property string songTitle: ""
    property string songArtist: ""
    property string coverUrl: ""
    property string lxLiveLyric: ""
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
    property double lastActiveMs: 0
    property int apiGeneration: 0
    property bool wsReconnectSuspended: false

    readonly property string currentLyric: currentLineIndex >= 0
        ? Lyrics.displayText(lyricLines[currentLineIndex], lyricMode)
        : (playerSource === "lx" && lyricLines.length === 0 ? lxLiveLyric : "")
    // The panel view owns karaoke HTML coloring to use its inherited theme.

    function numeric(value, fallback) {
        var n = Number(value)
        return isFinite(n) ? n : fallback
    }

    // Complete each request once. QML's XMLHttpRequest works directly from a plasmoid.
    // Using only the loopback host prevents remote hosts from receiving song metadata.
    function httpJson(method, path, payload, callback, asText) {
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
            if (asText) {
                finish(true, request.responseText)
            } else {
                try { finish(true, JSON.parse(request.responseText)) }
                catch (error) { finish(false, null) }
            }
        }
        request.onerror = function() { finish(false, null) }
        try {
            request.open(method, "http://127.0.0.1:" + currentApiPort + path, true)
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
        lxLiveLyric = ""
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
            if (isPlaying) lastActiveMs = Date.now()
            lyricLines = []
            lxLiveLyric = ""
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
        var wasPlaying = isPlaying
        isPlaying = !!playing
        if (isPlaying && (!wasPlaying || lastActiveMs === 0)) lastActiveMs = now
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

    function applyLxStatus(snapshot) {
        // LX Music Open API: progress/duration are seconds, not milliseconds.
        var name = typeof snapshot.name === "string" ? snapshot.name : ""
        var singer = typeof snapshot.singer === "string" ? snapshot.singer : ""
        var album = typeof snapshot.albumName === "string" ? snapshot.albumName : ""
        var seconds = Math.max(0, numeric(snapshot.duration, 0))
        var track = null
        if (name) {
            track = {
                id: "lx:" + JSON.stringify([name, singer, album, Math.round(seconds * 1000)]),
                title: name,
                artists: singer ? [{name: singer}] : [],
                cover: snapshot.picUrl || "",
                duration: seconds * 1000
            }
        }
        var changed = applyTrack(track)
        lxLiveLyric = typeof snapshot.lyricLineText === "string"
            ? snapshot.lyricLineText.replace(/\s+/g, " ").trim() : ""
        lyricOffsetMs = 0  // LRC [offset] is already included by LxLyrics.js
        setClock(numeric(snapshot.progress, 0) * 1000,
                 snapshot.status === "playing",
                 numeric(snapshot.playbackRate, 1), Date.now())
        return changed
    }

    function pollState(force) {
        if (!bridgeEnabled) return
        if (stateRequestPending && Date.now() - stateRequestStarted < 3000) return
        stateRequestPending = true
        stateRequestStarted = Date.now()
        var serial = ++stateRequestSerial
        var generation = apiGeneration
        var lx = playerSource === "lx"
        var endpoint = lx
            ? "/status?filter=status,name,singer,albumName,duration,progress,playbackRate,picUrl,lyricLineText"
            : "/api/now-playing"
        httpJson("GET", endpoint, null, function(ok, snapshot) {
            if (serial !== stateRequestSerial || generation !== apiGeneration) return
            stateRequestPending = false
            if (!ok || !snapshot || typeof snapshot !== "object"
                    || (lx && typeof snapshot.status !== "string")) {
                apiConnected = false
                isPlaying = false
                return
            }
            apiConnected = true
            if (lx) {
                var lxChanged = applyLxStatus(snapshot)
                if (trackId && (lxChanged || (!lyricLines.length &&
                        Date.now() - lastLyricAttempt > 12000))) fetchLyrics()
                return
            }
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
        if (!bridgeEnabled || !trackId || !apiConnected) return
        if (lyricRequestPending && Date.now() - lyricRequestStarted < 3500) return
        if (!force && Date.now() - lastLyricAttempt < 700) return
        var wantedId = trackId
        var generation = apiGeneration
        var serial = ++lyricRequestSerial
        lastLyricAttempt = Date.now()
        lyricRequestPending = true
        lyricRequestStarted = Date.now()
        if (playerSource === "lx") {
            // LX /lyric-all serves the player's own LRC, translation, romanization,
            // and optional lxlyric karaoke data. Fallback to /lyric plain text.
            httpJson("GET", "/lyric-all", null, function(ok, reply) {
                if (serial !== lyricRequestSerial || generation !== apiGeneration) return
                if (!ok || !reply || typeof reply !== "object") {
                    httpJson("GET", "/lyric", null, function(lrcOk, lrcText) {
                        if (serial !== lyricRequestSerial || generation !== apiGeneration) return
                        lyricRequestPending = false
                        if (!lrcOk || trackId !== wantedId) return
                        lyricLines = Lyrics.normalizeLines(LxLyrics.fromApi({lyric: lrcText}))
                        advanceClock()
                    }, true)
                    return
                }
                lyricRequestPending = false
                if (trackId !== wantedId) return
                lyricLines = Lyrics.normalizeLines(LxLyrics.fromApi(reply))
                advanceClock()
            })
            return
        }
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
        if (playerSource !== "splayer") return
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
        if (!bridgeEnabled || !apiConnected) return
        var op = command === "toggle" ? (isPlaying ? "pause" : "play") : command
        if (["play", "pause", "prev", "next", "stop", "seek"].indexOf(op) === -1) return
        var payload = op === "seek" ? {positionMs: Math.max(0, Math.round(positionMs))} : {}
        var controlGeneration = apiGeneration
        if (playerSource === "lx") {
            var paths = {play: "/play", pause: "/pause",
                         prev: "/skip-prev", next: "/skip-next"}
            var path = op === "seek"
                ? "/seek?offset=" + encodeURIComponent((payload.positionMs / 1000).toFixed(3))
                : paths[op]
            if (!path) return
            httpJson("GET", path, null, function(ok) {
                if (!ok || controlGeneration !== apiGeneration || playerSource !== "lx") return
                if (op === "seek") setClock(payload.positionMs, isPlaying, speed, Date.now())
                else if (op === "play" || op === "pause") isPlaying = op === "play"
                resyncTimer.restart()
            }, true)
            return
        }
        httpJson("POST", "/api/" + op, payload, function(ok, response) {
            if (controlGeneration !== apiGeneration || playerSource !== "splayer") return
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
        if (bridgeEnabled) pollState(true)
    }

    function deactivate() {
        apiGeneration++
        stateRequestSerial++
        stateRequestPending = false
        apiConnected = false
        clearTrack()
        wsConnected = false
        wsReconnectSuspended = true
        reconnectTimer.stop()
    }

    onPlayerSourceChanged: { if (initialized) resetConnection() }
    onApiPortChanged: { if (initialized && playerSource === "splayer" && bridgeEnabled) resetConnection() }
    onLxApiPortChanged: { if (initialized && playerSource === "lx" && bridgeEnabled) resetConnection() }
    onLyricModeChanged: { if (initialized) advanceClock() }
    onBridgeEnabledChanged: {
        if (initialized) {
            if (bridgeEnabled) resetConnection()
            else deactivate()
        }
    }
    Component.onCompleted: initialized = true

    Timer {
        id: bootstrapTimer
        interval: 200
        running: root.bridgeEnabled
        repeat: false
        onTriggered: root.pollState(true)
    }
    Timer {
        id: stateTimer
        interval: 900
        repeat: true
        running: root.bridgeEnabled
        onTriggered: root.pollState(false)
    }
    Timer {
        id: renderingTimer
        interval: 65
        repeat: true
        running: root.bridgeEnabled && root.apiConnected && root.isPlaying
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
        running: root.bridgeEnabled && root.apiConnected
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
        active: root.bridgeEnabled && root.playerSource === "splayer" && root.useWebSocket && !root.wsReconnectSuspended
        onStatusChanged: {
            if (status === WebSocket.Open) {
                root.wsConnected = true
                root.pollState(true)
                root.fetchLyrics(true)
            } else if (status === WebSocket.Error || status === WebSocket.Closed) {
                root.wsConnected = false
                if (root.bridgeEnabled && root.playerSource === "splayer" && root.useWebSocket && !root.wsReconnectSuspended) {
                    root.wsReconnectSuspended = true
                    reconnectTimer.restart()
                }
            }
        }
        onTextMessageReceived: function(message) { root.onSocketMessage(message) }
    }
}
