# TwigDock / 枝坞

> 一个用于统一管理本地端口、进程、Git 仓库与 Worktree 的原生 macOS 开发控制台。

[English](README.md) | [简体中文](README.zh-CN.md)

TwigDock（枝坞）把原本分散在 `lsof`、`ps`、终端标签页和 Git 命令中的本地开发状态集中到一个 macOS 应用里。它可以查看端口由哪个进程占用、把进程关联到对应仓库或 Worktree，并为常见的清理操作提供带保护的交互入口。

## 核心能力

- **项目总览**：按仓库聚合附加 Worktree 和项目启动的端口。
- **端口查看**：展示 TCP 监听、UDP 端点、进程名称、PID、命令、监听地址和运行目录。
- **项目关联**：通过进程当前工作目录，将端口关联到仓库或具体 Worktree。
- **安全管理进程**：支持浏览器打开本地服务、复制地址、打开终端，以及通过 `SIGTERM` 停止进程。
- **Worktree 管理**：查看分支、路径、未提交改动、上游、ahead/behind 和最近活动。
- **创建与移除 Worktree**：对脏工作树、强制移除和删除本地分支提供明确确认。
- **仓库排序与别名**：可将常用项目置顶，并添加类似 `attendance（日常考勤）` 的本地展示名称。
- **菜单栏速览**：项目端口和附加 Worktree 使用独立页签与滚动区域展示。
- **首次启动由用户配置**：TwigDock 不猜测默认扫描目录，必须由用户先选择目录。
- **原生与本地化**：使用 SwiftUI 开发，支持浅色/深色模式，无第三方运行时依赖。

## 下载

从 [GitHub Releases](https://github.com/Rudy-Ran/TwigDock/releases/latest) 下载最新版：

- **应用安装包**：[`TwigDock-macOS-arm64.zip`](https://github.com/Rudy-Ran/TwigDock/releases/latest/download/TwigDock-macOS-arm64.zip)
- **校验文件**：[`TwigDock-macOS-arm64.zip.sha256`](https://github.com/Rudy-Ran/TwigDock/releases/latest/download/TwigDock-macOS-arm64.zip.sha256)

如果只是想安装应用，不要下载 GitHub 自动生成的 **Source code** 压缩包。可以直接运行的应用是 Assets 区域中的 `TwigDock-macOS-arm64.zip`。

仓库及 Releases 均为公开内容，无需仓库权限即可下载。

## 安装

当前预构建版本要求：

- Apple Silicon Mac（`arm64`，M1 或更新芯片）
- macOS 13 Ventura 或更高版本
- Git
- 系统自带的 `lsof`

安装步骤：

1. 打开 [最新 Release](https://github.com/Rudy-Ran/TwigDock/releases/latest)。
2. 展开 **Assets**，下载 `TwigDock-macOS-arm64.zip`。
3. 双击 ZIP，解压得到 `TwigDock.app`。
4. 将 `TwigDock.app` 拖入 `/Applications`（应用程序）目录。
5. 打开 TwigDock，并选择需要扫描的代码仓库父目录。

### 首次打开与 Gatekeeper

当前预览版使用本机临时签名，**尚未经过 Apple 公证**，因此 macOS 第一次打开时可能阻止普通双击启动。

请使用 macOS 提供的标准方式：

1. 在 Finder 中按住 Control 点击 `TwigDock.app`，选择**打开**。
2. 如果弹窗提供**打开**按钮，再确认一次。
3. 如果仍然被拦截，进入**系统设置 → 隐私与安全性**，找到 TwigDock 的提示并选择**仍要打开**。

不要全局关闭 Gatekeeper。可参考 Apple 官方说明：[安全地打开 Mac 上的 App](https://support.apple.com/en-ca/102445)。

后续如需面向普通用户无提示分发，应使用 Apple Developer ID 签名并提交公证。参考：[Apple Developer ID](https://developer.apple.com/support/developer-id/)。

## 首次配置

TwigDock 启动后不会自动扫描任何目录：

1. 用户先选择代码目录，例如 `~/Developer` 或 `~/Desktop/Code`。
2. TwigDock 最多向下扫描四层来发现 Git 仓库。
3. `node_modules`、`DerivedData`、`dist` 等构建目录会被跳过。
4. 扫描目录、仓库顺序和展示别名保存在本机。

之后可以通过侧边栏左下角随时更改扫描目录。

## 端口关联原理

TwigDock 使用 macOS 系统工具读取端点和进程信息，再将进程当前工作目录与已发现的仓库、Worktree 路径进行匹配。

- 从仓库主目录中启动的进程会显示在对应项目下。
- 从附加 Worktree 中启动的进程会关联到该 Worktree。
- 无法读取工作目录或不属于扫描仓库的端点显示为“未关联”。
- 菜单栏中的项目端口页只展示已关联到项目的端口。

完成扫描目录配置后，端口数据每五秒自动刷新；仓库与 Worktree 数据支持手动刷新，并在增删操作完成后刷新。

## Worktree 行为与安全边界

- 仓库主目录只作为项目上下文，不计入附加 Worktree 数量。
- TwigDock 不允许移除仓库主目录。
- 移除 Worktree 会删除其工作目录，但不会删除仓库提交。
- 删除本地分支是可选操作，不会删除远程分支。
- 存在未提交改动时，必须开启强制移除并输入完整分支名确认。
- 可以在移除前停止关联的监听进程。
- 停止进程只发送 `SIGTERM`，不会使用 `SIGKILL`，也不会请求提升权限。
- TwigDock 会拒绝停止自身进程。

## 更新应用

1. 从菜单栏浮层退出 TwigDock，或使用 `Command-Q`。
2. 下载最新 Release 安装包。
3. 用新版 `TwigDock.app` 替换 `/Applications/TwigDock.app`。
4. 重新打开应用。

扫描目录、仓库排序和别名保存在应用包之外，替换应用时不会丢失。

## 从源码运行

环境要求：

- Swift 5.10 或更高版本
- macOS 13 SDK 或更高版本
- 推荐安装完整 Xcode，以支持 XCTest

克隆并运行：

```bash
git clone https://github.com/Rudy-Ran/TwigDock.git
cd TwigDock
swift run TwigDock
```

生成可双击运行的应用包：

```bash
./scripts/package-app.sh
open dist/TwigDock.app
```

打包脚本会执行 Release 构建、生成图标、创建 `dist/TwigDock.app` 并应用本机临时签名；它不会执行 Developer ID 签名或 Apple 公证。

## 验证

执行严格编译和可移植验证：

```bash
swift build -Xswiftc -warnings-as-errors
./scripts/verify.sh
```

安装完整 Xcode 后还可以运行：

```bash
swift test
```

可移植验证覆盖解析逻辑，以及基于临时 Git 仓库的 Worktree 操作；XCTest 还包含模型展示、端口行为、菜单栏过滤和旧配置迁移等回归测试。

## 隐私与权限

- TwigDock 没有账号系统，不包含数据分析或遥测。
- 项目配置只保存在本机 macOS 偏好设置中。
- 应用不会上传仓库内容。
- 应用未启用 App Sandbox，因为它需要检查本地进程以及用户选择的 Git 仓库。
- 浏览器操作只会打开用户主动选择的本地服务地址。

## 常见问题

### 没有发现某个仓库

- 确认仓库位于当前扫描目录之下。
- 深度超过四层的仓库不会被发现。
- 确认目录中包含有效 Git 元数据。
- 移动仓库后执行一次“刷新全部”。

### 端口显示为“未关联”

- 确认进程是在对应仓库或 Worktree 目录中启动的。
- 部分系统或受保护进程无法读取工作目录。
- 确认仓库位于当前配置的扫描目录内。

### 菜单栏看不到 TwigDock 图标

- 菜单栏过于拥挤或刘海屏空间不足时，macOS 可能隐藏状态项。
- 临时隐藏其他菜单栏图标，然后重启 TwigDock。
- 检查 Bartender、Ice 等菜单栏整理工具是否隐藏了 TwigDock。

### 下载后无法打开

当前预览版尚未经过 Apple 公证，请按照上面的[首次打开与 Gatekeeper](#首次打开与-gatekeeper)步骤操作，不要全局关闭 macOS 安全功能。

## 项目结构

```text
Sources/TwigDock/
  TwigDockApp.swift           应用窗口与菜单栏场景
  AppModel.swift              界面状态、持久化与操作编排
  Models.swift                领域模型与展示模型
  PortService.swift           lsof / ps 扫描与进程停止
  GitWorktreeService.swift    仓库发现与 Worktree 操作
  Views/                      原生中文 SwiftUI 界面
Tests/TwigDockTests/          XCTest 回归测试
Resources/Info.plist          应用包元数据
scripts/                      验证、图标生成与应用打包
```

## 当前版本限制

- 预构建安装包仅支持 Apple Silicon。
- 预览版使用本机临时签名，尚未经过 Apple 公证。
- 暂无自动更新能力。
- 仓库尚未添加软件许可证。

## 名字含义

`Twig` 表示轻量的 Git 分支或 Worktree；`Dock` 表示本地端口和开发上下文集中停靠的地方，同时也呼应 macOS Dock。
