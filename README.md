# SPlayer-Next Lyrics for KDE Plasma 6

See [中文安装与使用说明](README_CN.md).

A fork-inspired adaptation of [mhpsy/kde-splayer-lyrics](https://github.com/mhpsy/kde-splayer-lyrics) for SPlayer-Next's current HTTP/WebSocket API. The widget reads **only SPlayer-Next's locally parsed lyrics** (`/api/lyrics`), never querying LRCLIB, MPRIS song metadata, or any online lyrics service.

**Install**: enable SPlayer-Next External HTTP API (default localhost:14558), optionally WebSocket, then `bash install.sh` from this directory. KDE Plasma 6, and the Qt 6 WebSockets QML module, are required.

The panel widget hides completely, without reserving panel space, while the local HTTP API is unreachable, and reappears automatically when it reconnects. WebSocket is optional; HTTP connectivity controls visibility.

**Author**: qssn70. Original widget credit remains with mhpsy under the MIT license.

This is an independently packaged widget ID (`org.mhpsy.splayernext.lyrics`), so the original widget remains installed unchanged.

**Credit**: original widget by mhpsy, adaptation for SPlayer-Next. MIT per original repository's README.

## Plasma 6 package metadata fix (v1.1.2)

Adds the mandatory top-level `KPackageStructure: Plasma/Applet` metadata field and removes the obsolete `X-Plasma-MainScript` key. The old v1.1.0/v1.1.1 package lacked this field, so `kpackagetool6 -u` could not recognize the existing installation. Run `bash install.sh` from this source tree to repair only this widget's installed metadata and upgrade in place, preserving your Plasma widget configuration.
