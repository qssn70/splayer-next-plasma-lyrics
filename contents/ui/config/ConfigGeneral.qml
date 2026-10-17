import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    property string cfg_playerSource: plasmoid.configuration.playerSource
    property alias cfg_lxApiPort: lxPortField.value
    property alias cfg_apiPort: apiPortField.value
    property alias cfg_useWebSocket: useWebSocketCheck.checked
    property alias cfg_fontSize: fontSizeField.value
    property alias cfg_fontFamily: fontFamilyField.text
    property alias cfg_fontBold: fontBoldCheck.checked
    property alias cfg_fontItalic: fontItalicCheck.checked
    property alias cfg_useCustomColor: useCustomColorCheck.checked
    property alias cfg_fontColor: fontColorField.text
    property string cfg_animationType: plasmoid.configuration.animationType
    property alias cfg_animationDuration: animationDurationField.value
    property alias cfg_minWidth: minWidthField.value
    property alias cfg_maxWidth: maxWidthField.value
    property alias cfg_idleText: idleTextField.text
    property string cfg_lyricMode: plasmoid.configuration.lyricMode
    property alias cfg_showRomanInPopup: showRomanInPopupCheck.checked

    readonly property var playerSources: ["splayer", "lx"]
    readonly property var lyricModes: ["original", "translation", "bilingual", "romanization"]
    readonly property var animationModes: ["none", "fade", "slide", "slideFade"]

    Kirigami.FormLayout {
        anchors.fill: parent

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Player API")
        }
        ComboBox {
            id: sourceCombo
            Kirigami.FormData.label: i18n("Player:")
            model: ["SPlayer-Next", "LX Music / 洛雪音乐"]
            currentIndex: Math.max(0, configPage.playerSources.indexOf(configPage.cfg_playerSource))
            onActivated: function(index) { configPage.cfg_playerSource = configPage.playerSources[index] }
        }
        SpinBox {
            id: lxPortField
            Kirigami.FormData.label: i18n("LX Music HTTP port:")
            visible: configPage.cfg_playerSource === "lx"
            from: 1024
            to: 65535
        }
        SpinBox {
            id: apiPortField
            visible: configPage.cfg_playerSource !== "lx"
            Kirigami.FormData.label: i18n("Local API port:")
            from: 1024
            to: 65535
        }
        CheckBox {
            id: useWebSocketCheck
            visible: configPage.cfg_playerSource !== "lx"
            Kirigami.FormData.label: i18n("WebSocket events:")
            text: i18n("Enable faster track / lyrics updates")
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: configPage.cfg_playerSource === "lx"
                ? i18n("Enable LX Music Settings → Open API (default 23330). This widget reads /status and /lyric-all directly, including translations and lxlyric word timestamps. No online lyric search.")
                : i18n("Enable External API in SPlayer-Next settings. WebSocket is optional; HTTP-only mode still works. No online lyric search.")
            color: Kirigami.Theme.disabledTextColor
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Lyrics")
        }
        ComboBox {
            id: lyricModeCombo
            Kirigami.FormData.label: i18n("Panel lyrics:")
            model: [i18n("Original"), i18n("Translation preferred"),
                    i18n("Original + translation"), i18n("Romanization preferred")]
            currentIndex: Math.max(0, configPage.lyricModes.indexOf(configPage.cfg_lyricMode))
            onActivated: function(index) { configPage.cfg_lyricMode = configPage.lyricModes[index] }
        }
        CheckBox {
            id: showRomanInPopupCheck
            Kirigami.FormData.label: i18n("Expanded view:")
            text: i18n("Show romanization below the original")
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("Per-word highlighting uses SPlayer-Next word times or LX Music's lxlyric. Plain LRC lyrics remain line-synchronized.")
            color: Kirigami.Theme.disabledTextColor
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Font")
        }
        SpinBox {
            id: fontSizeField
            Kirigami.FormData.label: i18n("Font size (px):")
            from: 8
            to: 48
        }
        TextField {
            id: fontFamilyField
            Kirigami.FormData.label: i18n("Font family:")
            placeholderText: i18n("System font")
        }
        CheckBox { id: fontBoldCheck; Kirigami.FormData.label: i18n("Bold:") }
        CheckBox { id: fontItalicCheck; Kirigami.FormData.label: i18n("Italic:") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Color")
        }
        CheckBox {
            id: useCustomColorCheck
            Kirigami.FormData.label: i18n("Custom color:")
            text: i18n("Use an explicit text color")
        }
        Flow {
            Kirigami.FormData.label: i18n("Presets:")
            spacing: Kirigami.Units.smallSpacing
            enabled: useCustomColorCheck.checked
            Layout.fillWidth: true
            Repeater {
                model: ["#FFFFFF", "#FF9CAD", "#FF8C42", "#6CEABC", "#74B9FF", "#B19CD9"]
                delegate: Rectangle {
                    width: Kirigami.Units.gridUnit * 2
                    height: width
                    radius: width / 2
                    color: modelData
                    border.width: fontColorField.text === modelData ? 3 : 1
                    border.color: Kirigami.Theme.highlightColor
                    MouseArea {
                        anchors.fill: parent
                        onClicked: fontColorField.text = modelData
                    }
                }
            }
        }
        TextField {
            id: fontColorField
            Kirigami.FormData.label: i18n("Text color:")
            enabled: useCustomColorCheck.checked
            placeholderText: "#ffffff"
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Animation")
        }
        ComboBox {
            id: animationTypeCombo
            Kirigami.FormData.label: i18n("Transition:")
            model: [i18n("None"), i18n("Fade"), i18n("Slide"), i18n("Slide + Fade")]
            currentIndex: Math.max(0, configPage.animationModes.indexOf(configPage.cfg_animationType))
            onActivated: function(index) { configPage.cfg_animationType = configPage.animationModes[index] }
        }
        SpinBox {
            id: animationDurationField
            Kirigami.FormData.label: i18n("Duration (ms):")
            from: 50
            to: 1000
            stepSize: 50
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Layout")
        }
        SpinBox {
            id: minWidthField
            Kirigami.FormData.label: i18n("Minimum width:")
            from: 50
            to: 600
            stepSize: 10
        }
        SpinBox {
            id: maxWidthField
            Kirigami.FormData.label: i18n("Maximum width:")
            from: 100
            to: 1200
            stepSize: 50
        }
        TextField {
            id: idleTextField
            Kirigami.FormData.label: i18n("Idle text:")
            placeholderText: "♪ Music Lyrics"
        }
        Rectangle {
            Layout.fillWidth: true
            height: Kirigami.Units.gridUnit * 2.5
            radius: 6
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.Theme.disabledTextColor
            Text {
                anchors.centerIn: parent
                text: "♪ 歌词预览 · Preview Lyrics"
                font.pixelSize: fontSizeField.value
                font.family: fontFamilyField.text.length > 0 ? fontFamilyField.text : Kirigami.Theme.defaultFont.family
                font.bold: fontBoldCheck.checked
                font.italic: fontItalicCheck.checked
                color: useCustomColorCheck.checked ? fontColorField.text : Kirigami.Theme.textColor
            }
        }
    }
}
