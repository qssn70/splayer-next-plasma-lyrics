import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Adapted from mhpsy/kde-splayer-lyrics; consumes normalized SPlayer-Next lines.
ColumnLayout {
    id: fullRoot

    property string currentLyric: ""
    property bool isPlaying: false
    property bool apiConnected: false
    property string songTitle: ""
    property string songArtist: ""
    property string coverUrl: ""
    property real currentTimeMs: 0
    property real durationMs: 0
    property var lyricLines: []
    property int currentLineIndex: -1
    property bool showRomanization: false

    signal controlCommand(string cmd, real positionMs)

    Layout.preferredWidth: Kirigami.Units.gridUnit * 23
    Layout.preferredHeight: Kirigami.Units.gridUnit * 22
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Rectangle {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
            radius: 6
            color: Kirigami.Theme.backgroundColor
            border.color: coverImage.status === Image.Ready ? "transparent" : Kirigami.Theme.disabledTextColor
            border.width: 1
            clip: true
            Image {
                id: coverImage
                anchors.fill: parent
                source: coverUrl
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                sourceSize.width: parent.width * 2
                sourceSize.height: parent.height * 2
            }
            Label {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: Kirigami.Units.gridUnit * 2
                color: Kirigami.Theme.disabledTextColor
                visible: coverImage.status !== Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label {
                text: songTitle.length > 0 ? songTitle : "尚未播放音乐"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.3
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
                color: Kirigami.Theme.textColor
            }
            Label {
                text: songArtist
                visible: songArtist.length > 0
                elide: Text.ElideRight
                Layout.fillWidth: true
                color: Kirigami.Theme.disabledTextColor
            }
            Label {
                text: currentLyric
                visible: currentLyric.length > 0
                font.italic: true
                elide: Text.ElideRight
                Layout.fillWidth: true
                color: Kirigami.Theme.highlightColor
            }
        }
    }

    Label {
        visible: !apiConnected
        text: "⚠ 请在 SPlayer-Next 中开启外部 HTTP API"
        color: Kirigami.Theme.negativeTextColor
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        clip: true

        ListView {
            id: lyricsListView
            anchors.fill: parent
            model: lyricLines
            spacing: 8
            currentIndex: fullRoot.currentLineIndex
            highlightMoveDuration: 200
            preferredHighlightBegin: height / 2 - Kirigami.Units.gridUnit
            preferredHighlightEnd: height / 2 + Kirigami.Units.gridUnit
            highlightRangeMode: ListView.ApplyRange
            clip: true

            delegate: ColumnLayout {
                width: lyricsListView.width
                spacing: 1
                property bool activeLine: index === lyricsListView.currentIndex
                Label {
                    Layout.fillWidth: true
                    text: modelData.text || ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: parent.activeLine
                        ? Kirigami.Theme.defaultFont.pixelSize * 1.2
                        : Kirigami.Theme.defaultFont.pixelSize
                    font.bold: parent.activeLine
                    color: parent.activeLine ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    opacity: parent.activeLine ? 1.0 : 0.55
                    padding: 1
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
                Label {
                    Layout.fillWidth: true
                    visible: !!modelData.translatedLyric
                    text: modelData.translatedLyric || ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: parent.activeLine ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                    opacity: parent.activeLine ? 0.9 : 0.65
                }
                Label {
                    Layout.fillWidth: true
                    visible: showRomanization && !!modelData.romanLyric
                    text: modelData.romanLyric || ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                    opacity: parent.activeLine ? 0.95 : 0.55
                }
            }
        }
        Label {
            anchors.centerIn: parent
            visible: lyricLines.length === 0
            text: apiConnected ? "当前曲目没有歌词" : "等待连接播放器…"
            color: Kirigami.Theme.disabledTextColor
        }
    }

    Slider {
        id: playbackSlider
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        from: 0
        to: durationMs > 0 ? durationMs : 1
        value: Math.min(currentTimeMs, to)
        enabled: apiConnected && durationMs > 0
        live: false
        onPressedChanged: {
            if (!pressed && enabled) fullRoot.controlCommand("seek", value)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        Label {
            text: formatTime(currentTimeMs)
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: Kirigami.Theme.disabledTextColor
        }
        Item { Layout.fillWidth: true }
        Label {
            text: formatTime(durationMs)
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: Kirigami.Theme.disabledTextColor
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing
        ToolButton {
            icon.name: "media-skip-backward"
            onClicked: fullRoot.controlCommand("prev", 0)
            enabled: apiConnected
        }
        ToolButton {
            icon.name: isPlaying ? "media-playback-pause" : "media-playback-start"
            onClicked: fullRoot.controlCommand("toggle", 0)
            enabled: apiConnected
            implicitWidth: Kirigami.Units.gridUnit * 3
            implicitHeight: Kirigami.Units.gridUnit * 3
        }
        ToolButton {
            icon.name: "media-skip-forward"
            onClicked: fullRoot.controlCommand("next", 0)
            enabled: apiConnected
        }
    }

    function formatTime(milliseconds) {
        var seconds = Math.floor(Math.max(0, milliseconds) / 1000)
        return Math.floor(seconds / 60) + ":" + (seconds % 60 < 10 ? "0" : "") + seconds % 60
    }
}
