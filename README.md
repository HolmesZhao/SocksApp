# SocksApp

SocksApp 是一个运行在 iPhone / iPad 上的本地 SOCKS5 代理工具。它监听设备的个人热点或局域网地址，让同一网络内的电脑或其他设备可以通过 iOS 设备转发网络请求。

本项目是对 SocksBypass 思路的 Swift / SwiftUI 重写：UI 使用 SwiftUI，核心代理逻辑沉到 `SocksCore`，并补上认证、端口配置、流量统计、日志、二维码分享和单元测试。

## 功能

- SOCKS5 TCP `CONNECT` 转发
- SOCKS5 `UDP_ASSOCIATE` 转发
- 默认用户名/临时 token 认证，用户名为 `socks`
- 可切换开放模式，适合受控局域网内临时调试
- 默认监听端口 `5151`，可在 App 内修改
- 自动识别 `bridge100` / `en0` 的 IPv4 地址
- 网络变化后自动刷新监听地址并重启服务
- 上传/下载累计流量、实时速度、连接数和运行时长展示
- 代理信息复制、分享和二维码展示
- 本地日志页，便于排查连接、认证和转发问题
- 后台音频保活，使用 `blank.wav` 静音循环播放
- 中英文文案，资源位于 `SocksApp/Resources/Localizable.xcstrings`

## 项目结构

```text
.
├── Package.swift
├── SocksApp.xcodeproj
├── SocksApp
│   ├── App
│   │   ├── ContentView.swift
│   │   ├── SocksAppModel.swift
│   │   ├── BackgroundAudioKeeper.swift
│   │   └── AppDelegate.swift
│   ├── Resources
│   │   ├── Localizable.xcstrings
│   │   └── blank.wav
│   └── Sources/SocksCore
│       ├── SocksServer.swift
│       ├── SocksProtocol.swift
│       ├── SocksUDPRelay.swift
│       ├── NetworkInterfaceProvider.swift
│       └── ...
├── SocksAppTests/SocksCoreTests
└── client-sa-docs
```

`SocksCore` 可以通过 Swift Package 单独测试，iOS App 则通过 Xcode 工程构建运行。

## 环境要求

- Xcode 15 或更新版本
- Swift 5.9
- iOS 17 或更新版本
- macOS 14 或更新版本，用于本地运行 Swift Package 测试

建议使用真机验证代理能力。模拟器通常无法完整覆盖个人热点、局域网入站连接和后台保活行为。

## 运行

用 Xcode 打开工程：

```sh
open SocksApp.xcodeproj
```

选择 `SocksApp` scheme 和一台 iPhone / iPad 真机，点击 Run。

也可以用命令行查看工程配置：

```sh
xcodebuild -list -project SocksApp.xcodeproj
```

## 使用方式

1. 在 iOS 设置中开启个人热点，或确保 iPhone / iPad 与客户端设备处于同一局域网。
2. 打开 SocksApp，App 会自动启动 SOCKS5 服务。
3. 在首页查看监听地址和端口，例如 `192.168.1.23:5151`。
4. 默认使用认证模式：

```text
类型: SOCKS5
服务器: App 首页显示的 IP
端口: 5151
用户名: socks
密码: App 首页显示的临时 token
```

如果切换到开放模式，客户端无需用户名和密码：

```text
socks5://<ip>:5151
```

认证模式下，App 会生成完整代理 URL：

```text
socks5://socks:<token>@<ip>:5151
```

可以在 App 内复制完整代理 URL，或用另一台设备扫描二维码。

## 测试

运行 Swift Package 测试：

```sh
swift test
```

当前测试覆盖核心协议解析、端口解析、流量统计、日志存储、UDP 数据报和场景配置等基础行为。

## 实现说明

- `SocksAppModel` 管理 App 状态、端口、认证模式、网络变化、日志和后台保活。
- `SocksServer` 基于 Network.framework 的 `NWListener` / `NWConnection` 实现 TCP 监听和转发。
- `SocksHandshake` 和 `SocksRequestParser` 负责 SOCKS5 握手、用户名密码认证和请求解析。
- `SocksUDPRelay` 使用 Darwin UDP socket 实现 `UDP_ASSOCIATE` 数据报转发。
- `NetworkInterfaceProvider` 优先选择 `bridge100` 和 `en0` 上的 IPv4 地址。
- `BackgroundAudioKeeper` 通过极低音量循环播放 `blank.wav`，配合 `UIBackgroundModes` 中的 `audio` / `processing` 尽量维持后台运行。

## 注意事项

- 这个工具适用于授权调试和个人网络场景，不建议暴露到不受信任的网络。
- 开放模式不会校验用户名密码，只应在可控网络内短时间使用。
- 临时 token 当前由 App 运行时生成，重新生成后服务会重启。
- UDP 转发目前按 IPv4 socket 路径实现，IPv6 UDP 场景需要额外验证或扩展。
- iOS 对后台运行有系统级限制，即使启用后台音频，也不应假设服务可无限期稳定驻留后台。
- 如果首页提示没有可用网络接口，请先开启个人热点或切换到可被局域网访问的网络后重试。

## 相关文档

- `client-sa-docs/socks-bypass-ios-client-sa-v1.md`
- `client-sa-docs/socks-bypass-ios-client-sa-v2.md`

这些文档记录了从 SocksBypass 参考项目到当前 iOS SOCKS5 App 的客户端设计分析，可用于继续补需求、系分或实现细节。
