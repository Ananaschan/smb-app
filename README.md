# SMB 文件

通过 SMB 访问局域网 Windows 共享文件的 iPadOS / iPhone 文件管理器。

## 当前功能
- iPad 三栏布局与 iPhone 导航布局，服务器手动添加与 Bonjour `_smb._tcp` 局域网发现，默认缩略图预览，支持按名称、日期和升/降序排列
- 图片查看、缩放、保存原图到系统相册
- MP4 / MOV / MKV / AVI 等视频在线播放，支持外挂字幕
- 新建文件、新建文件夹、重命名、删除

## 技术栈
- SwiftUI，iOS 16+
- AMSMB2 4.0.3：SMB2/3 目录浏览、文件操作
- MobileVLCKit 3.6.0：MKV、字幕、4K 硬解播放
- XcodeGen + CocoaPods：Windows 上用文本文件维护工程，云端生成 `.xcodeproj`

## 构建与安装
1. 把代码推送到私有仓库的 `main` 分支，或手动触发 `Build IPA` workflow。
2. 运行成功后下载 `SMBPlayer-unsigned` Artifact（`.ipa`）。
3. Windows 上打开 Sideloadly，连接 iPad/iPhone，用免费 Apple ID 自签安装。
4. 免费 Apple ID 安装 7 天有效，到期后用 Sideloadly 重新签名安装。

## 目录结构
- `project.yml`：XcodeGen 工程定义
- `Podfile`：MobileVLCKit 依赖
- `SMBPlayer/`：App 源码（模型、SMB 服务、图片、播放器、视图）
- `Tests/`：单元测试
- `.github/workflows/build-ipa.yml`：macOS 云端构建 IPA
