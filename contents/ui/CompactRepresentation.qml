import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "Lyrics.js" as Lyrics

// Retains the layout/animation concept of mhpsy's SPlayer Lyrics plasmoid.
MouseArea {
    id: compactRoot

    property string currentLyric: ""
    // Receive raw timestamps, not precolored HTML from an offscreen PlayerBridge.
    // Theme colors must be resolved in the panel representation itself.
    property var lyricLine: null
    property real lyricTimeMs: 0
    property string lyricMode: "original"
    readonly property color resolvedTextColor: useCustomColor
        ? fontColor : Kirigami.Theme.textColor
    readonly property color resolvedHighlightColor: Kirigami.Theme.highlightColor
    readonly property string karaokeMarkup: lyricLine
        ? Lyrics.karaokeMarkup(lyricLine, lyricTimeMs, lyricMode,
                              htmlHex(resolvedHighlightColor), htmlHex(resolvedTextColor)) : ""

    // Qt's QColor.toString() may yield alpha-inclusive hex which isn't reliably
    // accepted by QTextDocument's limited HTML/CSS subset. Use #RRGGBB.
    function htmlHex(colorValue) {
        function channel(component) {
            var n = Math.max(0, Math.min(255, Math.round(component * 255)))
            return ("0" + n.toString(16)).slice(-2)
        }
        return "#" + channel(colorValue.r) + channel(colorValue.g) + channel(colorValue.b)
    }
    property bool isPlaying: false
    property bool apiConnected: false
    property string idleText: "♪ Music Lyrics"
    property int fontSize: 13
    property string fontFamily: ""
    property bool fontBold: false
    property bool fontItalic: false
    property bool useCustomColor: false
    property string fontColor: "#ffffff"
    property string animationType: "slide"
    property int animationDuration: 300
    property int maxWidth: 400
    property int minWidth: 150
    property string sourceLabel: ""
    property bool showSourceLabel: false
    property string songTitle: ""
    property string songArtist: ""

    signal togglePlayback()
    signal expandRequested()
    property bool initialized: false
    Component.onCompleted: initialized = true

    readonly property string displayText: {
        if (!apiConnected) return ""
        var line = currentLyric.length > 0 ? currentLyric
            : (songTitle.length > 0 ? "♪ " + songTitle : idleText)
        return showSourceLabel ? sourceLabel + "  " + line : line
    }

    // Also collapse the direct-panel representation to zero width when offline.
    // This avoids a blank slot if the panel ignores HiddenStatus for its layout.
    visible: apiConnected
    implicitHeight: lyricLabel.implicitHeight + Kirigami.Units.smallSpacing
    Layout.fillHeight: apiConnected
    Layout.preferredWidth: apiConnected
        ? Math.min(Math.max(lyricLabel.implicitWidth + Kirigami.Units.smallSpacing * 2,
                            minWidth), maxWidth) : 0
    Layout.minimumWidth: apiConnected ? Math.min(minWidth, maxWidth) : 0
    Layout.maximumWidth: apiConnected ? maxWidth : 0
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    onClicked: function(mouse) {
        if (mouse.button === Qt.MiddleButton) togglePlayback()
        else expandRequested()
    }
    hoverEnabled: true
    ToolTip.visible: containsMouse && songTitle.length > 0
    ToolTip.text: songTitle + (songArtist.length > 0 ? " - " + songArtist : "")
    ToolTip.delay: 500

    Item {
        anchors.fill: parent
        clip: true

        Text {
            id: lyricLabel
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing

            textFormat: karaokeMarkup.length > 0 && currentLyric.length > 0
                        ? Text.RichText : Text.PlainText
            // Rich text has its own HTML color rules. Wrap the entire line in
            // the actual panel text color; word spans override only as needed.
            text: textFormat === Text.RichText
                ? '<span style="color:' + compactRoot.htmlHex(compactRoot.resolvedTextColor) + ';">'
                    + (showSourceLabel ? "<b>" + sourceLabel + "</b>&nbsp; " : "")
                    + karaokeMarkup + '</span>'
                : displayText
            elide: Text.ElideRight
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: fontSize
            font.family: fontFamily.length > 0 ? fontFamily : Kirigami.Theme.defaultFont.family
            font.bold: fontBold
            font.italic: fontItalic
            color: compactRoot.resolvedTextColor
            opacity: 1
        }
    }

    // Animation only on line changes, not on per-word karaoke color updates.
    onDisplayTextChanged: {
        if (!initialized) return
        fadeAnimation.stop()
        slideAnimation.stop()
        slideFadeAnimation.stop()
        lyricLabel.opacity = 1
        lyricLabel.anchors.verticalCenterOffset = 0
        if (animationType === "fade") fadeAnimation.start()
        else if (animationType === "slide") slideAnimation.start()
        else if (animationType === "slideFade") slideFadeAnimation.start()
    }

    SequentialAnimation {
        id: fadeAnimation
        NumberAnimation { target: lyricLabel; property: "opacity"; from: 1; to: 0.2; duration: Math.max(1, animationDuration / 2) }
        NumberAnimation { target: lyricLabel; property: "opacity"; from: 0.2; to: 1; duration: Math.max(1, animationDuration / 2) }
    }
    SequentialAnimation {
        id: slideAnimation
        NumberAnimation { target: lyricLabel; property: "anchors.verticalCenterOffset";
            from: 0; to: -lyricLabel.height; duration: Math.max(1, animationDuration / 2) }
        PropertyAction { target: lyricLabel; property: "anchors.verticalCenterOffset"; value: lyricLabel.height }
        NumberAnimation { target: lyricLabel; property: "anchors.verticalCenterOffset";
            from: lyricLabel.height; to: 0; duration: Math.max(1, animationDuration / 2) }
    }
    SequentialAnimation {
        id: slideFadeAnimation
        ParallelAnimation {
            NumberAnimation { target: lyricLabel; property: "opacity";
                from: 1; to: 0.2; duration: Math.max(1, animationDuration / 2) }
            NumberAnimation { target: lyricLabel; property: "anchors.verticalCenterOffset";
                from: 0; to: -lyricLabel.height; duration: Math.max(1, animationDuration / 2) }
        }
        PropertyAction { target: lyricLabel; property: "anchors.verticalCenterOffset"; value: lyricLabel.height }
        ParallelAnimation {
            NumberAnimation { target: lyricLabel; property: "opacity";
                from: 0.2; to: 1; duration: Math.max(1, animationDuration / 2) }
            NumberAnimation { target: lyricLabel; property: "anchors.verticalCenterOffset";
                from: lyricLabel.height; to: 0; duration: Math.max(1, animationDuration / 2) }
        }
    }
}
