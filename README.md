# TwigDock / 枝坞

TwigDock（枝坞）是一个中文原生 macOS 开发者工具，把本机监听端口、对应进程、Git 仓库与 Worktree 放在同一个界面里管理。

## 功能

- 总览：按仓库聚合附加 Worktree，并显示主目录与各工作树启动的端口。
- 项目排序：总览仓库卡片支持拖动、置顶、上移和下移，顺序会持久保存。
- 显示名称：可为仓库增加本地备注，例如 `attendance（日常考勤）`，并同步显示在端口与 Worktree 页面。
- 端口管理：扫描 TCP 监听和 UDP 端点，展示进程、PID、命令、运行目录与项目关联。
- 进程操作：浏览器打开、复制地址、打开终端，以及通过 `SIGTERM` 安全停止进程。
- Worktree 管理：查看脏状态、ahead/behind、上游与最近提交。
- 新建 Worktree：选择仓库和基准分支，可复制常用 `.env` 文件。
- 移除 Worktree：可复制分支名，并用高亮选项确认停止关联进程、强制移除或删除本地分支。
- 首次配置：首次启动必须由用户选择代码目录，选择前不会执行任何扫描。
- 自动刷新：完成目录配置后，端口每 5 秒刷新一次，仓库数据可手动刷新。
- 菜单栏速览：点击状态栏图标可在独立页签中查看项目端口和附加 Worktree；系统端口不会出现在浮层中。
- 原生体验：SwiftUI、浅色/深色模式、无第三方依赖。

## 系统要求

- macOS 13 或更高版本
- Git 与系统自带的 `lsof`
- 从源码构建需要 Swift 5.10 或完整 Xcode

## 运行

开发模式：

```bash
swift run TwigDock
```

生成可双击运行的 `.app`：

```bash
./scripts/package-app.sh
open dist/TwigDock.app
```

打包脚本会执行 Release 构建、生成应用图标并进行本机 ad-hoc 签名。产物位于 `dist/TwigDock.app`。

## 验证

有完整 Xcode 时可运行：

```bash
swift test
```

只有 Apple Command Line Tools、没有 XCTest 时，可运行核心解析与临时 Git 仓库集成验证：

```bash
./scripts/verify.sh
```

## 工作方式与安全边界

- 扫描目录必须由用户首次选择，可在左下角更改并持久保存；应用不会猜测默认目录。
- 仓库主目录只用于端口归属和创建基准，不计入 Worktree 数量或管理列表。
- 仓库发现最多向下扫描 4 层，并跳过 `node_modules`、`DerivedData`、`dist` 等构建目录。
- 端口与 Worktree 的关联依据进程当前工作目录；无法读取工作目录时显示为“未关联”。
- 停止进程只发送 `SIGTERM`，不会使用 `SIGKILL`，也不会尝试提升权限。
- TwigDock 会拒绝停止自身；进程已经退出时按成功处理。
- 主工作树受保护，不能从 TwigDock 中移除。
- 删除含未提交改动的 Worktree 必须开启强制移除并输入完整分支名。
- 应用未启用 App Sandbox，因为它需要读取本机进程、仓库以及用户选择的目录。

## 项目结构

```text
Sources/TwigDock/
  AppModel.swift              界面状态与操作编排
  PortService.swift           lsof / ps 扫描与进程停止
  GitWorktreeService.swift    仓库发现与 Worktree 操作
  Views/MenuBarView.swift     菜单栏项目端口与工作树速览
  Views/                      中文 SwiftUI 界面
Tests/TwigDockTests/          XCTest 解析回归测试
scripts/                      验证、图标生成与 .app 打包
```
