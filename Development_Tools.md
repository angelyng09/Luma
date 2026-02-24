# Luma 开发工具清单（概要 + 安装/部署提示）

## 1. 基础开发环境

- **macOS**（用于 iOS 开发）
- **Xcode**（IDE、编译、调试、真机部署）
- **Swift / SwiftUI**（主要开发语言与 UI 框架）

### 安装/部署提示

- **Xcode 安装**：通过 App Store 安装最新版 Xcode。首次打开需要同意许可并完成组件下载。
- **命令行工具**：在终端执行 `xcode-select --install` 安装 Xcode Command Line Tools。
- **模拟器与真机**：Xcode 的“Settings > Platforms”里可安装模拟器；真机需用 Apple ID 登录并在“Signing & Capabilities”配置团队。

## 2. iOS 关键能力与框架

- **Speech / AVFoundation**：语音识别与音频采集
- **AVSpeechSynthesizer**（TTS）：语音播报
- **CoreLocation / MapKit**：地点检索与定位（基础版本）
- **Camera / AVFoundation**：二维码扫描
- **Accessibility API**：VoiceOver 适配、动态字体、高对比度

### 安装/部署提示

- 这些框架均为 **iOS 系统内置**，无需额外安装。
- 需要在 Xcode 项目中启用相应权限（如麦克风、语音识别、相机）。
- 建议在 `Info.plist` 中配置用途说明（NSMicrophoneUsageDescription、NSSpeechRecognitionUsageDescription、NSCameraUsageDescription）。

## 3. 数据与后端（可选）

- **SQLite / Core Data**：本地缓存（轻量存储）
- **后端服务**（如 Firebase / 自建 API）
  - 用户、地点、评论、二维码信息与实时反馈

### 安装/部署提示

- **Core Data / SQLite**：无需额外安装，按需在 Xcode 项目中引入。
- **Firebase（可选）**：在 Firebase 控制台创建项目，下载 iOS 配置文件并引入 SDK（可用 Swift Package Manager）。
- **自建 API（可选）**：准备后端域名与 HTTPS 证书，iOS 端配置接口地址与环境切换（Dev / Prod）。

## 4. 设计与协作

- **Figma / Sketch**：原型与界面设计
  - https://www.bilibili.com/video/BV1n3iMByEug/?spm_id_from=333.337.search-card.all.click&vd_source=08f6829b1a05f1ab4ce50d000c4f4463
- **Notion / 飞书文档**：需求与进度管理
- **Git + GitHub**：版本管理与协作

### 安装/部署提示

- **Git**：macOS 通常自带，可用 `git --version` 检查；没有的话会提示安装。
- **设计工具**：Figma/Sketch 按需安装桌面版或使用网页版。
- **协作工具**：创建团队空间与权限规则，建立需求/里程碑模板。

## 5. 测试与调试

- **Xcode Simulator / 真机**：功能验证
- **Accessibility Inspector**：无障碍测试
- **TestFlight**：内测分发

### 安装/部署提示

- **Accessibility Inspector**：随 Xcode 安装，可在 Xcode 的 Developer Tools 中打开。
- **TestFlight**：在 App Store Connect 创建 App，完成签名与上传后邀请测试者。

## 6. 分析与运营（可选）

- **Firebase Analytics / App Store Connect**：基础数据指标
- **Crashlytics**：崩溃分析

### 安装/部署提示

- **Analytics / Crashlytics**：通常随 Firebase SDK 安装；确保按隐私要求提示与合规配置。

## 7. VSCode + Codex 插件（Swift 编程辅助）

- **VSCode**：用于代码编辑与 AI 编程辅助。
- **Codex 插件**：在 VSCode 扩展商店搜索并安装，登录后可使用 AI 生成/重构 Swift 代码。
- **Swift 支持**：推荐安装 Swift 语言扩展（语法高亮、补全）；编译与运行仍建议通过 Xcode 完成。

### 建议工作流

1. 在 VSCode 中用 Codex 编写/重构 SwiftUI 代码。
2. 在 Xcode 中编译、运行模拟器与真机。
3. 通过 Xcode 的调试工具与 Accessibility Inspector 验证无障碍体验。
