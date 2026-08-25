# SMB 文件开发问题记录

## 当前状态

- iOS App 已能通过 GitHub Actions 编译出未签名 IPA。
- 最新 IPA 已包含 `AMSMB2.framework`，启动闪退问题已修复。
- Sideloadly 自签安装后，还需要继续验证 SMB 浏览和播放功能。
- 导航跳转已改用 destination-based `NavigationLink`（见第 7 条），待真机验证。
- 最新真机日志确认：主机→共享→图片浏览链路已通；剩余问题与图片查看器交互已修（见第 8、9 条）。

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

### 7. SwiftUI 导航：value-based NavigationLink 找不到 navigationDestination

现象：

```text
A NavigationLink is presenting a value of type AppRoute
but there is no matching navigationDestination declaration
visible from the location of the link. The link cannot be activated.
```

点击主机无法进入共享列表。

排查过程：

- 最初：`navigationDestination(for: SMBServer.self)` / `(for: SMBShare.self)` 挂在各自 `List` 上，
  iOS 17/18 下 lazy container 内的注册对链接不可见，报 Fault。
- 提交 `e4e8c9d`：统一为 `AppRoute` 枚举，把 `navigationDestination(for: AppRoute.self)` 注册到外层
  `NavigationStack` 的直接子视图上（文档推荐位置），但新构建日志仍报同样 Fault。
- 类型与注册位置均无误（`SMBServer`/`SMBShare` 都 Hashable），判断为 iOS 18 下
  value-based `NavigationLink` + `navigationDestination(for:)` 查找不稳定的已知问题，
  在 `RootView` 按 `horizontalSizeClass` 条件切换 `NavigationStack`/`NavigationSplitView` 的结构下尤其明显。

解决：

- 服务器列表、共享列表全部改为 destination-based 链接，不依赖 `navigationDestination` 注册：

```swift
NavigationLink {
    ShareListView(server: server)
} label: { ... }
```

```swift
NavigationLink {
    BrowseView(server: server, share: share.name)
} label: { ... }
```

- 删除不再使用的 `AppRoute` 枚举和外层注册。
- 该写法 iOS 16/17/18 均直接生效，不经过注册表查找。

待真机验证：

- 点主机 → 共享列表
- 点共享 → 根目录
- 点文件夹 → 下一层（若仍出现"退回上一层"，下一步考虑把 `BrowseView` 内层嵌套的
  `NavigationStack` 拍平，把子文件夹路径并入外层栈）

### 8. 首次进入子文件夹被弹回，第二次点击正常

现象（新构建真机日志确认）：

- 第一次点文件夹：push 进去后立刻退回上一层
- 再点一次：正常进入，图片/子目录都能显示
- 主机→共享→根目录链路已正常（destination-based 链接生效）

原因：

- `BrowseView` 内层 `NavigationStack(path: $pathStack)` + `navigationDestination(for: String.self)`
  在 iOS 18/26 下首次 push 不稳定：path 绑定或注册查找在栈刚建立时失效，导致 push 被撤销。

解决：

- 内层导航也改为 destination-based `NavigationLink { directoryView(path: item.path) } label: {...}`
- 删除 `pathStack` 状态和 `navigationDestination(for: String.self)` 注册
- 新建文件夹操作改为按当前目录层级传 `path`（`performCreate(in:)`）

### 9. 图片查看器交互改进

按用户要求调整：

- 保存原图成功后弹轻提示"已保存到相册"：小号胶囊样式、弱化存在感，0.5 秒后自动消失，不需要手动点确认
- 保存失败仍弹错误提示
- 左右滑动切换同一文件夹内的图片（TabView 分页）
- 向下拖拽/下滑退出图片查看，返回文件夹网格（拖到阈值释放即退出，未到阈值回弹）
- 顶部显示 `当前页 / 总数` 计数

### 10. 图片缓存管理（已临时回退）

> 状态：**已临时移除**——排查编译器挂起用。构建恢复后重新加回。

- 图片缩略图/原图磁盘缓存上限 4 GB（`ImageLoader.maxCacheBytes`）
- 缓存超过上限后自动按"修改时间从旧到新"清理，清到上限的 70%，避免频繁清理
- 单文件超过 500 MB 不缓存
- 内存缓存上限 128 MB
- 设置页（首页/侧边栏工具栏齿轮按钮）显示缓存占用与文件数，可一键手动清除缓存

### 11. SwiftCompile 编译挂起（待定位）

现象：

- `xcodebuild` 在 `SwiftCompile`（App 的 Swift 源码编译）步骤挂起，超过 3 小时无输出
- 正常构建约 5 分钟；两次不同机器上复现
- 失败运行能在 1~2 分钟内快速报出编译错误，说明新代码类型检查本身不慢

排查进度：

- 已临时移除缓存相关代码（ImageLoader 恢复原版、删除设置页、移除齿轮入口），验证是否为触发源
- 若仍挂起，下一步回退 `ImageViewerView` 重写（TabView 分页 + enumerated 遍历）
- 工作流已加 `timeout-minutes: 30` 防止无限消耗 Actions 额度

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
