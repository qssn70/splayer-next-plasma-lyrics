# Music Lyrics — KDE Plasma 6 任务栏歌词

在 [mhpsy/kde-splayer-lyrics](https://github.com/mhpsy/kde-splayer-lyrics) 基础上适配的 KDE Plasma 6 歌词小组件。**同时支持 SPlayer-Next 和 LX Music（洛雪音乐）开放 API**。

**重要：只从播放器的本机 API 获取已加载的歌词。** 小组件不调用 LRCLIB、不通过 MPRIS 获取歌名并搜索歌词，也不向在线歌词服务发送歌曲信息。

## v1.3.0：默认自动切换与双歌词

- **默认自动模式**：同时监测 SPlayer-Next 和 LX Music 的本地 API。只有一个播放器在播放时，只显示该播放器的歌词。
- **两个播放器同时播放**：任务栏并列增加两个独立歌词位，标记为 `SPlayer` 和 `LX`；各自同步进度、逐字高亮和动画。展开视图也会并列展示两套歌词及各自的播放控制。
- **暂停或停止**：如果只有一个播放器仍在播放，就只显示正在播放的播放器；如果都没有播放，优先保留最近播放过的已连接播放器。
- **API 断线**：任意一个可用时仍显示对应歌词；两个 API 都无法访问时，整个小组件隐藏并释放任务栏空间，恢复后自动显示。
- **手动模式**：在组件设置的 `Selection mode` 中选择 `Manual`，再选 `SPlayer-Next` 或 `LX Music`。手动模式只监测所选播放器，不显示双歌词。
- 两个播放器分别使用端口 `14558` 与 `23330`。小组件不联网搜索歌词，仍然直接读取各播放器的已加载歌词。


## 新增 LX Music（v1.2.0）

- LX Music 默认端口 `23330`，可单独设置，不影响原 SPlayer-Next 端口 `14558`
- `GET /status` 获取歌曲名称、播放/暂停状态、进度与速度，官方单位为**秒**；组件转换为毫秒
- `GET /lyric-all` 直接读取播放器中当前曲目的原文 `lyric`、翻译 `tlyric`、音译 `rlyric` 与逐字歌词 `lxlyric`；如果接口不可用，回退 `GET /lyric`（纯 LRC 文本）
- 识别普通 LRC 时间标签、多时间标签、`[offset]` 和 LX 的 `<起点毫秒,时长毫秒>歌词` 逐字标签
- LX 播放控制按其协议发起 GET，例如 `/skip-next`、`/pause`、`/seek?offset=60.000`（seek 单位为秒）
- LX 无须 WebSocket。暂采用约 900ms 一次的状态校准请求和客户端时间插值；歌词随切歌重新加载，另每 12 秒兜底刷新

## 原功能不变

- 面板单行歌词、字体颜色和过渡动画、双语与罗马音、展开的多行歌词及播放进度控制
- SPlayer-Next HTTP API 与可选 WebSocket 保持支持，支持其 LRC/TTML/YRC 等解析后的歌词与逐字时间
- 作者为 `qssn70`，保留原作者 `mhpsy` 的 MIT 许可证和来源署名
- 组件 ID 保持 `org.mhpsy.splayernext.lyrics`，升级不需要重新加入面板

## 系统要求

- Kubuntu / KDE Plasma 6
- SPlayer-Next（选择它时），或 LX Music Desktop 2.7.0 及以上（选择洛雪时）
- Qt 6 WebSockets QML 插件（即使仅选择 LX Music，主 QML 仍会加载相关模块）：Kubuntu 通常是 `qml6-module-qtwebsockets`

## 安装或升级

```bash
sudo apt install qml6-module-qtwebsockets
git clone https://github.com/qssn70/splayer-next-plasma-lyrics.git
cd splayer-next-plasma-lyrics
bash install.sh
```

此前已克隆该仓库：在源码目录执行 `git pull && bash install.sh` 即可更新。

`install.sh` 会检查旧版的 `KPackageStructure` 元数据并原地升级，不删除旧面板部件或用户配置。若 Plasma 没自动刷新，可重新登录 KDE 会话。

在 KDE 面板中右键 → 添加部件 → 搜索 **Music Lyrics**。右键小组件 → 配置 → **Player** 选择播放器。

### SPlayer-Next

打开 SPlayer-Next「设置 → 外部 API」，启用 HTTP API，默认端口 `14558`。WebSocket 是可选项，启用时还需打开 WebSocket。

```bash
curl -s http://127.0.0.1:14558/api/now-playing | python3 -m json.tool
curl -s http://127.0.0.1:14558/api/lyrics | python3 -m json.tool
```

### LX Music（洛雪音乐）

打开洛雪音乐桌面版「设置 → 开放 API → 启用开放 API 服务」，默认端口 `23330`；无需打开 WebSocket。

```bash
curl -s http://127.0.0.1:23330/status | python3 -m json.tool
curl -s http://127.0.0.1:23330/lyric-all | python3 -m json.tool
curl -s http://127.0.0.1:23330/lyric
```

其中 `/lyric` 返回原始 LRC 文本，不是 JSON。`/lyric-all` 会直接给出原文、翻译、音译和（有时提供）逐字歌词。若播放器当前无歌词，小组件也无法凭空显示歌词；当有歌曲但没有完整歌词时，可以退而显示播放器 `/status` 提供的 `lyricLineText`。

## 已知限制

- LX Music 状态目前通过 HTTP 轮询而非官方提供的 SSE 订阅接口，因此切歌检测最多可能延迟约 1 秒
- 逐字高亮需要 `lxlyric` 或 SPlayer-Next 的逐字时间数据；普通 LRC 只支持逐行同步
- 图片展示仅支持 QML 可访问的封面地址；私有 Electron 协议可能只显示音符占位
- 不能在当前构建环境直接执行 Plasma 桌面联调；请在 Kubuntu 上验证实际样式与网络连接

## 检查与测试

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

官方文档：[洛雪开放 API](https://lxmusic.toside.cn/desktop/open-api)、[LX 逐字歌词格式](https://lxmusic.toside.cn/desktop/custom-source)。

## 作者和许可

本修改版作者：**qssn70**。

原小组件项目：[mhpsy/kde-splayer-lyrics](https://github.com/mhpsy/kde-splayer-lyrics)（MIT）。保留原许可证及版权说明；SPlayer-Next、LX Music 为独立上游项目。
