# UURadio (iRadio)

网络电台播放器，支持电台收听、IPTV 视频与对讲（PTT）功能，覆盖 Android / iOS / HarmonyOS 平台。

## 功能特性

- **电台播放**：电台浏览、分类筛选、搜索、收藏、播放历史，音频可视化与调谐台风格播放界面
- **IPTV**：网络电视频道列表与点播播放
- **对讲（PTT）**：按住说话，语音经 WebRTC 在设备间点对点直连；信令中继服务器仅负责房间注册、SDP/ICE 定向路由与话权仲裁，不处理任何音频数据
- **多语言**：中 / 英文界面

## 目录结构

```
.
├── frontend_flutter/     # Flutter 客户端（Android / iOS）
│   └── lib/features/     # browse 电台浏览、player 播放器、tv 视频、intercom 对讲、settings 设置等
├── frontend_ohos/        # HarmonyOS 客户端（ArkTS）
├── server/intercom/      # 对讲信令中继服务器（Go + WebSocket）
└── data/                 # 电台频道数据（radio_stations.db / .json）
```

## 快速开始

### Flutter 客户端

```bash
cd frontend_flutter
flutter pub get
flutter run
```

### 对讲信令服务器

```bash
cd server/intercom
go run ./cmd/relay -addr :8090
```

客户端通过 `ws://<服务器地址>:8090/ws` 接入。

### HarmonyOS 客户端

使用 DevEco Studio 打开 `frontend_ohos` 目录，同步依赖后构建运行。

## 许可证

本项目基于 [GPL v2](LICENSE) 许可证开源。
