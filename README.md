# Music Lyrics for KDE Plasma 6 — SPlayer-Next / LX Music

[中文使用说明](README_CN.md)

A KDE Plasma 6 panel lyrics widget adapted from [mhpsy/kde-splayer-lyrics](https://github.com/mhpsy/kde-splayer-lyrics).

**No online lyric search:** the widget reads only lyrics that the selected local player already provides through its own API. It never calls LRCLIB or uses MPRIS metadata to look up lyrics.

## Supported local players

| Player | Default loopback port | Direct lyric API | Status API | Playback control |
| --- | ---: | --- | --- | --- |
| [SPlayer-Next](https://github.com/SPlayer-Dev/SPlayer-Next) | 14558 | `GET /api/lyrics` | `GET /api/now-playing` | `POST /api/{play,pause,prev,next,seek}` |
| [LX Music Desktop](https://github.com/lyswhut/lx-music-desktop) 2.7+ | 23330 | `GET /lyric-all`, `/lyric` fallback | `GET /status` | `GET /play`, `/pause`, `/skip-prev`, `/skip-next`, `/seek?offset=<seconds>` |

LX Music's `/lyric-all` contains LRC text, translations, romanization and optionally `lxlyric` **per-word** data; all are parsed locally. SPlayer-Next delivers its already-parsed LyricLine objects. Both players can be monitored independently in automatic mode (default); manual selection is also available.

## Automatic selection and simultaneous playback (v1.3.0)

- **Default: Automatic.** Both loopback APIs are monitored. When one player is playing, the panel follows only that player.
- **Both playing:** the taskbar shows **two independent lyric slots** labeled `SPlayer` and `LX`, separated by a line. Both have their own lyric text, per-word timing, animations and middle-click pause/play actions. Expanding the widget shows both lyric lists and controls side by side.
- **Neither playing:** retain the most recently active connected player; if no recent activity is known, prefer the connected player with a loaded track, then SPlayer-Next. If both APIs are unreachable, hide the entire applet without using panel space.
- **Manual:** Widget configuration -> Selection mode -> Manual -> choose SPlayer-Next or LX Music. Other player is not polled in manual mode.
- Switching modes does not change the widget ID, the saved port numbers or visual settings.

## Install / update

```bash
sudo apt install qml6-module-qtwebsockets
bash install.sh
```

The script repairs the older v1.1.0/1.1.1 missing Plasma 6 `KPackageStructure` metadata and upgrades in place. The widget ID **does not change** (`org.mhpsy.splayernext.lyrics`), so existing panel placements and settings remain intact.

Then right-click the panel → **Add Widgets** → **Music Lyrics**. In widget settings choose Automatic (default) or Manual, configure both local API ports, and enable the corresponding player Open/External APIs. SPlayer's optional WebSocket requires a separate setting in SPlayer. LX Music uses local HTTP requests and needs no WebSocket.

## Features

- One-line panel lyrics with animations, selectable color/font, and expandable multi-line view
- Plain LRC timing; SPlayer-Next and LX Music `lxlyric` word-by-word highlighting
- Translation / romanization / bilingual display when the player supplies it
- Playback controls and seek, with the respective player's documented methods and time units
- **Hide the widget and release panel space when both enabled APIs are unreachable; automatically show again when either recovers**
- HTTP playback polling and local clock interpolation (900ms / 65ms); optional SPlayer WebSocket for immediate change notification
- Original upstream credit and MIT license retained

## Test the APIs

```bash
# SPlayer-Next
curl -s http://127.0.0.1:14558/api/now-playing
curl -s http://127.0.0.1:14558/api/lyrics

# LX Music (enable Settings → Open API first)
curl -s http://127.0.0.1:23330/status
curl -s http://127.0.0.1:23330/lyric-all
```

LX Music API source: [official Open API specification](https://lxmusic.toside.cn/desktop/open-api) and [LX `lxlyric` format](https://lxmusic.toside.cn/desktop/custom-source). This project only **displays** the lyric data the players already have; they may independently fetch lyrics according to their own settings.

## Testing

```bash
node tests/lyrics.test.cjs
node tests/lx-lyrics.test.cjs
node tests/api.test.cjs
node tests/lx-api.test.cjs
node tests/http.test.cjs
node tests/selection.test.cjs
node tests/concurrent-api.test.cjs
python3 tests/check_structure.py
```

These exercise the QML JavaScript logic and metadata without a running Plasma desktop. Live KDE Plasma 6 / LX Music integration should also be verified on Linux.

**Author:** qssn70. **Original project:** [mhpsy/kde-splayer-lyrics](https://github.com/mhpsy/kde-splayer-lyrics). **License:** MIT.

## v1.3.1: Dark theme lyric color fix

Fixed karaoke text appearing black on dark Plasma panels, particularly with LX Music
`lxlyric` tracks. The panel representation now resolves its own theme foreground and
highlight colors and encodes them as six-digit HTML colors, rather than receiving
precolored rich text from an offscreen player controller. Original text, translation,
romaji and both simultaneous-lyrics slots follow the active panel theme. Existing
custom text color settings still take precedence.
