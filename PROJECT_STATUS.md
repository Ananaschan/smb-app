# SMB 文件项目状态

## 项目目标

开发一个运行在 iPadOS / iPhone 上的局域网文件管理器，通过 SMB 协议访问 Windows 共享文件夹，实现：

- 浏览服务器、共享和目录，默认使用缩略图预览
- 支持按名称、日期以及升/降序排列
- 打开并缩放查看图片，一键把原图保存到系统相册
- 在线流畅播放 4K 视频，支持 MKV、外挂字幕和音轨切换
- 新建文件、新建文件夹、重命名、删除等常规文件管理
- 自动跟随系统深色模式
- 适配 iPhone 和 iPad 布局
- 在 Windows 上开发，通过 GitHub Actions 编译未签名 IPA，再用 Sideloadly 自签安装

## 技术方案

- 原生 SwiftUI，最低支持 iOS 16
- AMSMB2 4.0.3：SMB2/3 连接、目录浏览、文件操作
- MobileVLCKit 3.6.0：MKV/MP4/AVI 等视频播放、4K 硬解、外挂字幕
- XcodeGen + CocoaPods：Windows 端维护文本工程定义，云端生成 Xcode 工程
- GitHub Actions macOS runner：产出未签名 IPA 供 Sideloadly 使用

## 仓库信息

- 本地路径：`C:\code\personal\SMB-IpadOS`
- 远端仓库：`https://github.com/Ananaschan/smb-app.git`（私有）
- 当前分支：`main`

## 完成进度

### 已完成

- 工程骨架：`project.yml`、`Podfile`、资源目录和 `.gitignore`
- CI 构建流水线：`.github/workflows/build-ipa.yml`
- SMB 服务层：共享枚举、目录枚举、读取、下载、新建、重命名、删除
- 服务器管理：手动添加、Keychain 保存密码、删除
- Bonjour `_smb._tcp` 局域网自动发现
- 文件浏览：缩略图网格和列表切换
- 排序：按名称、按日期、升序/降序
- 图片查看：全屏缩放、底部左侧保存原图按钮、写入系统相册
- 视频播放：VLCKit 播放器、缓冲设置、进度控制、字幕选择
- 自适应布局：iPad 三栏、iPhone 导航栈
- 深色模式：使用系统语义色，跟随系统外观
- 单元测试：路径拼接、父路径、排序逻辑
- 使用文档：`README.md`

### 待验证

- GitHub Actions 首次编译，修复可能的 Swift/Xcode 编译问题
- Sideloadly 真机自签安装
- Windows 共享真实连接，验证 guest、账号、域账号登录
- 中文文件名、大文件、空目录等边界情况
- 4K H.264/HEVC MP4/MKV 在局域网中的实际流畅度
- 外挂字幕自动匹配和手动选择
- iPhone 和 iPad 真机横竖屏、深色模式切换

## 下次工作

1. 推送代码，运行 `Build IPA` workflow
2. 根据编译日志修复问题，直到产出有效 IPA
3. 使用 Sideloadly 安装到真机
4. 连接真实 Windows 共享，按“待验证”清单逐项测试
5. 如 VLCKit 直连 SMB 播放不稳定，再实现 AMSMB2 本地 HTTP Range 代理作为播放兜底

