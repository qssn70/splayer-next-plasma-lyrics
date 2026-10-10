# SPlayer-Next Lyrics — KDE Plasma 6 面板歌词

基于 [mhpsy/kde-splayer-lyrics](https://github.com/mhpsy/kde-splayer-lyrics) 的 KDE Plasma 6 小组件改造，针对 [SPlayer-Next](https://github.com/SPlayer-Dev/SPlayer-Next) 当前外部 API。

**歌词唯一来源：SPlayer-Next 本机 `/api/lyrics`。** 不使用 LRCLIB，不利用 MPRIS 查询歌曲名称，不向外部歌词站发送歌曲信息。SPlayer-Next 可读取本地 LRC、TTML、YRC 等歌词，组件展示播放器实际解析后的结果。

## 功能

- KDE 任务栏直接显示实时同步歌词；点击展开歌词列表、时间轴和上一曲/暂停/下一曲按钮
- HTTP API 获取歌词、播放时间、偏移、歌曲信息；WebSocket 用于加快切歌及歌词更新（可关闭）
- 支持逐字时间高亮（逐字歌词）、逐行歌词（LRC）、原文/翻译/双语/音译模式
- 可配置字体、颜色、切换动画、宽度、端口；按中键播放/暂停
- HTTP-only 模式，无须启用 WebSocket；播放器断线后持续尝试重连
- **API 未连接时自动隐藏任务栏小组件且不保留空白占位**；HTTP API 恢复后自动重新显示，无需手动操作
- 单独的组件 ID，不会覆盖原版 SPlayer Lyrics

## 系统要求

- Kubuntu / KDE Plasma 6
- SPlayer-Next，已开启「设置 → 外部 API → HTTP API」；默认端口 `14558`
- 若需要 WebSocket 事件，另外开启「WebSocket」；如只开 HTTP，将组件配置里的 WebSocket 开关关闭
- Qt 6 WebSockets QML 插件。Kubuntu 常见包名：`qml6-module-qtwebsockets`（不同版本略有差别）

## 安装

从 zip 解压后进入 `splayer-next-plasma-lyrics` 目录：

```bash
sudo apt install qml6-module-qtwebsockets
bash install.sh
```

或者直接从可安装的 `.plasmoid` 文件安装：

```bash
kpackagetool6 -t Plasma/Applet -i splayer-next-lyrics.plasmoid
```

已安装同 ID 时使用 `-u` 代替 `-i`。**注意：旧的 v1.1.0/v1.1.1 曾遗漏 `KPackageStructure` 元数据，无法直接 `-u`；请使用本源码自带的 `bash install.sh` 自动修复旧版的元数据，再升级。该修复只修改本组件的 JSON 元数据，不删除 KDE 面板上的小组件，也不清除用户配置。**

然后右键 KDE 任务栏 → 添加部件 → 搜索 `SPlayer-Next Lyrics` → 放入面板。

## 检查 API

```bash
curl -s http://127.0.0.1:14558/api/now-playing | python3 -m json.tool
curl -s http://127.0.0.1:14558/api/lyrics | python3 -m json.tool
```

第一条应返回 `track`、`position`、`sendTimestamp` 等字段，第二条应有 `lyric` 数组。播放有歌词的歌测试。若请求失败，请在播放器设置开启外部 API，确认端口一致。

## 使用说明

- **面板文字颜色**使用系统主题，卡拉 OK 逐字激活部分采用 KDE 主题强调色
- **原文 + 翻译**在面板同一行使用 `·` 拼接，展开窗口显示多行双语
- **音译优先**仅在 SPlayer-Next 已解析并提供 `romanLyric` 时显示，否则回退到原文
- **封面**仅显示 QML 可访问的 HTTP(S)/file URL，SPlayer 自定义私有协议封面会显示音符占位图；歌词不受影响
- **无网络歌词抓取**指小组件本身不进行在线歌词查找；播放器自身如何获取歌词取决于播放器设置

## 原理

- `GET http://127.0.0.1:14558/api/now-playing`：每 900ms 校准播放进度、歌曲身份、速度、歌词偏移
- `GET http://127.0.0.1:14558/api/lyrics`：首次/切歌/歌词变化时加载完整 `LyricLine[]`，每 12 秒兜底刷新
- `ws://127.0.0.1:14558/ws`（可选）：监听 `track`、`lyric`、`lyricOffset`，不依赖高频位置事件
- 使用 `sendTimestamp`、播放速度和本机时钟，在 HTTP 查询间隔内以 65ms 更新歌词显示

## Plasma 6 元数据修复（v1.1.2）

- `metadata.json` 顶层添加必需的 `"KPackageStructure": "Plasma/Applet"`。
- 去掉 Plasma 6 已不再使用的 `X-Plasma-MainScript`。
- `install.sh` 会先补齐旧版已安装元数据，再正常执行 `kpackagetool6 -u`。也可以手工修改旧版 `metadata.json` 后再运行 `kpackagetool6 -u`。

## 测试及已知限制

`node tests/lyrics.test.cjs` 测试歌词正规化、时间定位、双语及富文本转义。完整 Plasma UI 与本机播放器的联调需要在 Kubuntu Plasma 6 中进行。

## 作者与来源

本修改版组件作者：**qssn70**（组件元数据中的作者字段）。


基于 [mhpsy/kde-splayer-lyrics](https://github.com/mhpsy/kde-splayer-lyrics)（README 标注 MIT）；其原组件外观、动画、弹出歌词和配置模式经过保留及适配。修改版的新增代码亦采用 MIT 许可。SPlayer-Next 为独立上游项目。
