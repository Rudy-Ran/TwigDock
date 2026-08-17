# TwigDock

> A native macOS control center for local ports, processes, Git repositories, and Worktrees.

[English](README.md) | [简体中文](README.zh-CN.md)

TwigDock (枝坞) brings the local development state that is usually scattered across `lsof`, `ps`, terminal tabs, and Git commands into one focused macOS app. It shows which processes own local ports, links them back to scanned repositories and Worktrees, and provides guarded actions for common cleanup tasks.

## Highlights

- **Project overview** — groups additional Worktrees and project-owned ports by repository.
- **Port inspection** — shows TCP listeners and UDP endpoints with process name, PID, command, address, and working directory.
- **Project association** — links a process to a repository or Worktree by inspecting its current working directory.
- **Safe process control** — opens local services in a browser, copies addresses, opens Terminal, and sends `SIGTERM` when stopping a process.
- **Worktree management** — shows branch, path, dirty state, upstream, ahead/behind state, and recent activity.
- **Create and remove Worktrees** — includes explicit confirmation for destructive or dirty-worktree operations.
- **Repository aliases and ordering** — keeps frequently used projects at the top and supports local display names such as `attendance (Daily Attendance)`.
- **Menu bar overview** — provides compact, independently scrollable pages for project ports and additional Worktrees.
- **Explicit first-run setup** — TwigDock never guesses a scan directory; the user must choose one before scanning begins.
- **Native and local** — built with SwiftUI, supports light and dark appearance, and has no third-party runtime dependencies.

## Download

Download the newest build from [GitHub Releases](https://github.com/Rudy-Ran/TwigDock/releases/latest):

- **Application:** [`TwigDock-macOS-arm64.zip`](https://github.com/Rudy-Ran/TwigDock/releases/latest/download/TwigDock-macOS-arm64.zip)
- **Checksum:** [`TwigDock-macOS-arm64.zip.sha256`](https://github.com/Rudy-Ran/TwigDock/releases/latest/download/TwigDock-macOS-arm64.zip.sha256)

Do not download GitHub's automatically generated **Source code** archives unless you intend to build TwigDock yourself. The runnable app is the asset named `TwigDock-macOS-arm64.zip`.

The repository and its Releases are public, so the application can be downloaded without repository access.

## Install

Current prebuilt releases require:

- Apple Silicon Mac (`arm64`, M1 or newer)
- macOS 13 Ventura or newer
- Git
- The system-provided `lsof`

Installation steps:

1. Open the [latest release](https://github.com/Rudy-Ran/TwigDock/releases/latest).
2. Expand **Assets** and download `TwigDock-macOS-arm64.zip`.
3. Double-click the ZIP file to extract `TwigDock.app`.
4. Drag `TwigDock.app` into `/Applications`.
5. Open TwigDock and choose the parent directory that contains the repositories you want it to scan.

### First launch and Gatekeeper

The current preview build is ad-hoc signed and **not notarized by Apple**. macOS may therefore block a normal double-click on first launch.

Use the standard macOS flow:

1. In Finder, Control-click `TwigDock.app` and choose **Open**.
2. Confirm **Open** in the dialog, if offered.
3. If macOS still blocks the app, open **System Settings → Privacy & Security**, find the TwigDock notice, and choose **Open Anyway**.

Do not disable Gatekeeper globally. See Apple's guide: [Safely open apps on your Mac](https://support.apple.com/en-ca/102445).

For a frictionless public release, the app should later be signed with an Apple Developer ID and notarized. See [Apple Developer ID](https://developer.apple.com/support/developer-id/).

## First-run setup

TwigDock intentionally starts without scanning anything.

1. Choose a code directory, for example `~/Developer` or `~/Desktop/Code`.
2. TwigDock searches for Git repositories up to four directory levels below that root.
3. Build folders such as `node_modules`, `DerivedData`, and `dist` are skipped.
4. The chosen directory, repository order, and aliases are stored locally.

You can change the scan directory later from the bottom of the sidebar.

## How port association works

TwigDock reads local endpoint and process information with macOS system tools, then compares each process's current working directory with discovered repository and Worktree paths.

- A process running inside a main repository directory is shown under that project.
- A process running inside an additional Worktree is linked to that Worktree.
- If the working directory cannot be read or does not belong to a scanned repository, the endpoint remains unassociated.
- Only project-associated ports appear in the menu bar's project-port page.

Port data refreshes every five seconds after a scan directory has been configured. Repository and Worktree data refreshes manually and after mutations.

## Worktree behavior and safety

- The repository's main working directory is used as project context but is not counted as an additional Worktree.
- The main working directory cannot be removed from TwigDock.
- Removing a Worktree deletes its working directory, not repository commits.
- Deleting a local branch is optional and never deletes its remote branch.
- A dirty Worktree requires force removal and an exact branch-name confirmation.
- Associated listening processes can be stopped before removal.
- Process stopping sends `SIGTERM`; TwigDock does not use `SIGKILL` or request elevated privileges.
- TwigDock refuses to stop its own process.

## Updating

1. Quit TwigDock from its menu bar panel or with `Command-Q`.
2. Download the newest release asset.
3. Replace the existing `/Applications/TwigDock.app` with the new version.
4. Reopen the app.

The scan directory, repository order, and aliases are stored separately from the application bundle and are retained during replacement.

## Build from source

Requirements:

- Swift 5.10 or newer
- macOS 13 SDK or newer
- Full Xcode is recommended for XCTest support

Clone and run:

```bash
git clone https://github.com/Rudy-Ran/TwigDock.git
cd TwigDock
swift run TwigDock
```

Create a double-clickable application bundle:

```bash
./scripts/package-app.sh
open dist/TwigDock.app
```

The packaging script performs a release build, generates the app icon, creates `dist/TwigDock.app`, and applies a local ad-hoc signature. It does not perform Developer ID signing or notarization.

## Verification

Run strict compilation and the portable verification suite:

```bash
swift build -Xswiftc -warnings-as-errors
./scripts/verify.sh
```

With a full Xcode installation, also run:

```bash
swift test
```

The portable verification suite covers parser behavior and Worktree operations against temporary Git repositories. XCTest provides additional regression coverage for model presentation, port behavior, menu bar filtering, and preference migration.

## Privacy and permissions

- TwigDock has no account system and no analytics or telemetry.
- Project configuration stays in local macOS preferences.
- The app does not upload repository contents.
- The app is not sandboxed because it needs to inspect local processes and Git repositories selected by the user.
- Browser actions only open local service URLs chosen by the user.

## Troubleshooting

### A repository is missing

- Confirm it is inside the configured scan root.
- Repositories deeper than four levels are not discovered.
- Confirm the directory contains valid Git metadata.
- Use **Refresh All** after moving repositories.

### A port is shown as unassociated

- Confirm the process was launched from inside the repository or Worktree.
- Some system or protected processes do not expose a readable working directory.
- Confirm the repository is under the configured scan root.

### The menu bar icon is not visible

- macOS can hide status items when the menu bar is crowded or when a display notch reduces available space.
- Hide another menu bar item temporarily and relaunch TwigDock.
- Check whether a menu bar organizer such as Bartender or Ice is hiding the item.

### The app cannot be opened after downloading

The current preview is not notarized. Follow the [First launch and Gatekeeper](#first-launch-and-gatekeeper) steps above. Do not disable macOS security globally.

## Project structure

```text
Sources/TwigDock/
  TwigDockApp.swift           Application and menu bar scenes
  AppModel.swift              UI state, persistence, and operation orchestration
  Models.swift                Domain and presentation models
  PortService.swift           lsof / ps scanning and process termination
  GitWorktreeService.swift    Repository discovery and Worktree operations
  Views/                      Native Chinese SwiftUI interface
Tests/TwigDockTests/          XCTest regression coverage
Resources/Info.plist          Application bundle metadata
scripts/                      Verification, icon generation, and packaging
```

## Current release limitations

- The prebuilt binary is Apple Silicon only.
- The preview build is ad-hoc signed and not notarized.
- There is no automatic updater yet.
- A software license has not yet been added to the repository.

## Name

`Twig` represents a lightweight Git branch or Worktree. `Dock` represents a place where local ports and development contexts can be gathered, while also nodding to macOS.
