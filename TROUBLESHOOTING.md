# SMB 文件开发问题记录

## 当前状态

- iOS App 已能通过 GitHub Actions 编译出未签名 IPA。
- 最新 IPA 已包含 `AMSMB2.framework`，启动闪退问题已修复。
- Sideloadly 自签安装后，还需要继续验证 SMB 浏览和播放功能。

## 已解决的问题

### 1. GitHub Actions 首次构建失败：缺少 AppIcon

现象：

```text
None of the input catalogs contained a matching app icon set named "AppIcon"
```

原因：工程没有 `AppIcon.appiconset`，Xcode 打包时找不到图标。

解决：

- 添加 `AppIcon.appiconset`
- 生成 1024x1024 的 `AppIcon.png`
- 在 `project.yml` 中显式设置 `ASSETCATALOG_COMPILER_APPICON_NAME`

### 2. Actions 版本与 Homebrew 警告

现象：

- `actions/checkout@v4` 提示 Node.js 20 deprecated
- Homebrew 提示 `aws/tap` 不受信任

解决：

- 更新到 `actions/checkout@v5.1.0`
- 更新到 `actions/upload-artifact@v6.0.0`
- 安装 XcodeGen 时设置 `HOMEBREW_NO_REQUIRE_TAP_TRUST=1`

### 3. MobileVLCKit 3.6.0 API 不兼容

现象：

```text
value of type 'VLCMediaPlayer' has no member 'timeChangeUpdateInterval'
value of type 'VLCMediaPlayer' has no member 'length'
```

原因：一开始按 VLCKit 最新版本接口写，但项目实际使用的是 `MobileVLCKit 3.6.0`，接口较旧。

解决：

- 删除 `timeChangeUpdateInterval`
- 时长改为从 `player.media?.length` 读取
- 进度 `position` 使用 `Float`
- 代理回调改为接收 `Notification`

### 4. SMBServerStore 初始化顺序错误

现象：

```text
'self' used in property access 'fileURL' before all stored properties are initialized
```

解决：给 `servers` 增加默认空数组，初始化时再读取磁盘上的服务器列表。

### 5. 自签后打开 App 秒退

崩溃日志关键信息：

```text
Library not loaded: @rpath/AMSMB2.framework/AMSMB2
termination: DYLD, Library missing
```

原因：AMSMB2 是 SPM 动态框架，App 二进制链接了它，但 IPA 的 `Frameworks` 里没有包含 `AMSMB2.framework`，导致 dyld 启动时找不到库。

解决：

- `project.yml` 显式设置 `embed: true`
- `Build IPA` 打包脚本在产物中查找 `AMSMB2.framework`
- 如果找不到就报错；找到则复制到 `Payload/SMBPlayer.app/Frameworks/`
- 已验证新 IPA 包含 `AMSMB2.framework`

### 6. Sideloadly 报 LOCKDOWN_E_MUX_ERROR

现象：

```text
Call to lockdownd_client_new_with_handshake failed: LOCKDOWN_E_MUX_ERROR
```

原因：Windows 上没有安装 Apple 的驱动组件，系统里没有 `Apple Mobile Device Service`。

解决：

- 安装 Microsoft Store 的 `Apple Devices`
- 或安装 Apple 官网的 iTunes for Windows
- 安装后重新插设备并信任电脑

## 当前待排查问题

### SMB 进入文件夹后自动退出/断开

现象：

- 手机进入共享文件夹后，画面退回上一层
- 之后再点主机列表，无法重新进入文件
- App 没有崩溃，系统没有新的崩溃日志

可能方向：

- 目录读取失败时错误处理不完整，列表显示成“空文件夹”或退回
- 断线后 `SMBFileService` 仍保留旧连接对象，没有真正重连
- 共享列表或文件列表失败后缺少“重试”入口

计划改进：

- 目录列表失败时显示完整错误状态和“重试”按钮
- 共享列表失败时同样显示“重试”
- 连接失败后清空旧 manager，下次操作重新连接
- 为浏览界面增加“刷新/重连”能力

## 在 Windows 上调试 iOS

### 无法直接在本机调试

Windows 上不能运行 Xcode 和 iOS 模拟器，也不能直接单步调试 iOS App。这个问题无法通过安装工具完全解决。

### App 持续日志

系统“分析与改进”里只会保存崩溃报告，普通运行日志不会出现在那里。

因此 App 内已增加自己的持续日志：

- App 启动时自动开始记录
- 日志文件位置：App 沙盒内的 `Documents/Logs/app.log`
- 记录 SMB 连接、共享枚举、目录读取、下载和错误信息
- 首页右上角有“导出日志”按钮，可把 `app.log` 分享出来

排查步骤：

1. 打开 App，复现“进入文件夹后退回、无法重新连接”
2. 回到主机列表首页
3. 点右上角“导出日志”按钮
4. 把日志文件发出来，即可定位断开原因

### 可以做到的前置调试

1. 纯逻辑单元测试
   - 排序、路径拼接、URL 构造等不依赖 UIKit 的代码可以在 CI 的 iOS 模拟器里用 XCTest 跑。
   - Windows 本机目前没有 Swift 工具链，但后续可以安装 Swift for Windows 来跑一部分纯 Swift 逻辑。

2. GitHub Actions 模拟器测试
   - 在 macOS runner 上执行 `xcodebuild test`
   - 在 iPhone 模拟器里启动 App，验证是否能正常进入首屏
   - 使用 `xcrun simctl launch` 启动 App，并抓取崩溃日志
   - 使用 `xcrun simctl io booted screenshot` 保存界面截图

3. 增加应用内日志
   - 在 SMB 连接、目录读取、错误捕获处输出 `OSLog` 或 `print`
   - 构建后通过 CI 日志或真机崩溃报告查看

4. 租用远程 Mac
   - 想真正用 Xcode 断点调试 UI/播放器，可以按小时租 Mac mini 或 Mac in Cloud。
   - 最接近原生 iOS 调试体验，但需要付费。

### 推荐路线

在没有 Mac 的情况下，最划算的方案是：

1. 先用 GitHub Actions 跑 iOS 模拟器单元测试和启动冒烟测试
2. 在 App 里加入足够详细的日志
3. SMB 目录问题优先靠日志定位
4. 实在难以定位时，再租远程 Mac 做 Xcode 真机断点调试
