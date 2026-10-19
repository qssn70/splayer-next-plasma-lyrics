import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "PlayerSelection.js" as Selection

// Both players are monitored in auto mode. Independent PlayerBridge instances
// prevent concurrent songs/HTTP replies from replacing each other's lyrics.
PlasmoidItem {
    id: root
    readonly property string selectionMode: plasmoid.configuration.selectionMode
    readonly property string manualPlayer: plasmoid.configuration.playerSource
    readonly property int apiPort: plasmoid.configuration.apiPort
    readonly property int lxApiPort: plasmoid.configuration.lxApiPort
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

    PlayerBridge {
        id: splayer
        playerSource: "splayer"
        bridgeEnabled: root.selectionMode !== "manual" || root.manualPlayer === "splayer"
        apiPort: root.apiPort
        lxApiPort: root.lxApiPort
        useWebSocket: root.useWebSocket
        lyricMode: root.lyricMode
    }
    PlayerBridge {
        id: lxmusic
        playerSource: "lx"
        bridgeEnabled: root.selectionMode !== "manual" || root.manualPlayer === "lx"
        apiPort: root.apiPort
        lxApiPort: root.lxApiPort
        useWebSocket: false
        lyricMode: root.lyricMode
    }

    // Active-playing status wins. Two playing players get two lyrics slots.
    // When neither plays, retain the most recently active connected player.
    readonly property var selected: Selection.choose(selectionMode, manualPlayer,
        {connected: splayer.apiConnected, playing: splayer.isPlaying,
         hasTrack: splayer.trackId.length > 0, lastActiveMs: splayer.lastActiveMs},
        {connected: lxmusic.apiConnected, playing: lxmusic.isPlaying,
         hasTrack: lxmusic.trackId.length > 0, lastActiveMs: lxmusic.lastActiveMs})
    readonly property bool showSplayer: selected.splayer
    readonly property bool showLX: selected.lx
    readonly property bool dualLyrics: selected.dual

    // Preserve the legacy behavior: when no enabled API is reachable, the
    // applet is hidden and consumes no space, but bridge timers keep polling.
    Plasmoid.status: (showSplayer || showLX)
        ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    onShowSplayerChanged: if (!showSplayer && !showLX) expanded = false
    onShowLXChanged: if (!showSplayer && !showLX) expanded = false

    preferredRepresentation: compactRepresentation
    compactRepresentation: RowLayout {
        id: panelRow
        spacing: Kirigami.Units.smallSpacing
        Layout.fillHeight: true

        CompactRepresentation {
            id: splayerLine
            apiConnected: root.showSplayer
            currentLyric: splayer.currentLyric
            lyricLine: splayer.currentLineIndex >= 0
                ? splayer.lyricLines[splayer.currentLineIndex] : null
            lyricTimeMs: splayer.currentTimeMs + splayer.lyricOffsetMs
            lyricMode: root.lyricMode
            songTitle: splayer.songTitle
            songArtist: splayer.songArtist
            isPlaying: splayer.isPlaying
            sourceLabel: "SPlayer"
            showSourceLabel: root.dualLyrics
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
            onTogglePlayback: splayer.sendControl("toggle", 0)
            onExpandRequested: root.expanded = !root.expanded
        }
        Rectangle {
            visible: root.dualLyrics
            Layout.preferredWidth: 1
            Layout.preferredHeight: Math.max(splayerLine.implicitHeight, lxLine.implicitHeight)
            color: Kirigami.Theme.disabledTextColor
            opacity: 0.6
        }
        CompactRepresentation {
            id: lxLine
            apiConnected: root.showLX
            currentLyric: lxmusic.currentLyric
            lyricLine: lxmusic.currentLineIndex >= 0
                ? lxmusic.lyricLines[lxmusic.currentLineIndex] : null
            lyricTimeMs: lxmusic.currentTimeMs + lxmusic.lyricOffsetMs
            lyricMode: root.lyricMode
            songTitle: lxmusic.songTitle
            songArtist: lxmusic.songArtist
            isPlaying: lxmusic.isPlaying
            sourceLabel: "LX"
            showSourceLabel: root.dualLyrics
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
            onTogglePlayback: lxmusic.sendControl("toggle", 0)
            onExpandRequested: root.expanded = !root.expanded
        }
    }

    // Both full lyric timelines are available independently in dual mode.
    fullRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        FullRepresentation {
            playerLabel: root.dualLyrics ? "SPlayer-Next" : ""
            visible: root.showSplayer
            currentLyric: splayer.currentLyric
            isPlaying: splayer.isPlaying
            apiConnected: splayer.apiConnected
            songTitle: splayer.songTitle
            songArtist: splayer.songArtist
            coverUrl: splayer.coverUrl
            currentTimeMs: splayer.currentTimeMs
            durationMs: splayer.durationMs
            lyricLines: splayer.lyricLines
            currentLineIndex: splayer.currentLineIndex
            showRomanization: root.showRomanInPopup
            onControlCommand: function(cmd, positionMs) { splayer.sendControl(cmd, positionMs) }
        }
        FullRepresentation {
            playerLabel: root.dualLyrics ? "LX Music" : ""
            visible: root.showLX
            currentLyric: lxmusic.currentLyric
            isPlaying: lxmusic.isPlaying
            apiConnected: lxmusic.apiConnected
            songTitle: lxmusic.songTitle
            songArtist: lxmusic.songArtist
            coverUrl: lxmusic.coverUrl
            currentTimeMs: lxmusic.currentTimeMs
            durationMs: lxmusic.durationMs
            lyricLines: lxmusic.lyricLines
            currentLineIndex: lxmusic.currentLineIndex
            showRomanization: root.showRomanInPopup
            onControlCommand: function(cmd, positionMs) { lxmusic.sendControl(cmd, positionMs) }
        }
    }
}
