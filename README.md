# Godot OpenBlive 插件

<img src="icon.png?raw=true"  align="right" />

[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![AssetLib](https://img.shields.io/badge/AssetLib-OpenBlive-478cbf)](https://godotengine.org/asset-library/asset/1341)

哔哩哔哩[直播开放平台](https://open-live.bilibili.com/document/)的 Godot 插件。

* 长连 API
* 互动玩法 API

## 用法

启用插件后即可在场景中使用 OpenBlive 节点。

该节点有四个属性：

| 名称 | 说明 |
| ---- | ---- |
| `Access Key Id`     | 注册开放平台开发者获得。 |
| `Access Key Secret` | 注册开放平台开发者获得。 |
| `App Id`            | 项目 ID，使用互动玩法必填。 |
| `Room Id Override`  | 强制使用特定的直播间号。留空自动从命令行参数获取。<br />上架后从直播姬中运行时就会使用这种方式传递直播间号。 |

该节点有四个方法：

| 名称 | 说明 |
| ---- | ---- |
| `start_danmaku()` | 开启弹幕。成功开启后就可以通过信号收到事件通知。<br />开启的成功与否请以对应的信号为准。 |
| `stop_danmaku()`  | 关闭弹幕。 |
| `start_game()`    | 开启互动玩法。<br />开启的成功与否请以对应的信号为准。 |
| `stop_game()`     | 关闭互动玩法。 |

该节点的信号如下：

| 名称 | 说明 |
| ---- | ---- |
| `danmaku_server_connected` | 弹幕服务器已连接。 |
| `danmaku_server_connection_failed` | 弹幕服务器连接失败。 |
| `danmaku_server_disconnected` | 弹幕服务器已断开。 |
| `danmaku_received(data)` | 收到弹幕。<br />`data` 为字典，字段说明见[官方文档](https://open-live.bilibili.com/document/liveRoomData.html#%E8%8E%B7%E5%8F%96%E5%BC%B9%E5%B9%95%E4%BF%A1%E6%81%AF)。 |
| `gift_received(data)` | 收到礼物。<br />`data` 为字典，字段说明见[官方文档](https://open-live.bilibili.com/document/liveRoomData.html#%E8%8E%B7%E5%8F%96%E7%A4%BC%E7%89%A9%E4%BF%A1%E6%81%AF)。|
| `superchat_added(data)` | 添加付费留言。<br />`data` 为字典，字段说明见[官方文档](https://open-live.bilibili.com/document/liveRoomData.html#%E8%8E%B7%E5%8F%96%E4%BB%98%E8%B4%B9%E7%95%99%E8%A8%80)。|
| `superchat_removed(data)` | 删除付费留言。<br />`data` 为字典，字段说明见[官方文档](https://open-live.bilibili.com/document/liveRoomData.html#%E4%BB%98%E8%B4%B9%E7%95%99%E8%A8%80%E4%B8%8B%E7%BA%BF)。|
| `guard_hired(data)` | 大航海。<br />`data` 为字典，字段说明见[官方文档](https://open-live.bilibili.com/document/liveRoomData.html#%E4%BB%98%E8%B4%B9%E5%A4%A7%E8%88%AA%E6%B5%B7)。|
| `game_started` | 互动玩法已开启。<br />结束互动玩法后有一段时间的冷却结算期，如果在此期间内调用 `start_game()`，节点会自动进行等待。 |
| `game_start_failed(code)` | 互动玩法开启失败。<br />`code` 为整数错误码。为 `-1` 时表示非服务器返回的错误，其余情况见[官方文档](https://open-live.bilibili.com/document/doc&tool/auth.html#%E5%85%AC%E5%85%B1%E9%94%99%E8%AF%AF%E7%A0%81)。错误码为 `7001` 的情况已在内部处理自动重试，不会发生。 |
| `game_stopped` | 互动玩法已停止。 |

示例用法见 Demo。

