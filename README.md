# NoSleepBar

一个极简的 macOS 菜单栏工具：一键让电脑保持唤醒，不休眠、不息屏、不进入屏保；可设置开启时长，到期自动关闭并恢复系统原有设置。

## 功能

- **一键开关**：左键点击菜单栏图标直接切换；右键弹出菜单管理
- **定时关闭**：可选不限时 / 15 分钟 / 30 分钟 / 1 小时 / 2 小时 / 4 小时 / 8 小时，菜单栏实时显示剩余时间
- **状态可视**：开启显示太阳图标，关闭显示月亮图标，一眼可辨
- **开机自启**：可选，登录时自动启动并恢复上次的开启状态与剩余时长
- **无副作用**：通过电源断言实现，不修改 `pmset` 或屏保配置；关闭或崩溃时系统自动恢复原设置
- **无需权限**：不需要管理员权限、不需要辅助功能权限

## 安装与使用

当前版本已安装到 `/Applications/NoSleepBar.app`，可直接在“应用程序”中打开。启动后菜单栏出现月亮图标，无 Dock 图标。

| 操作 | 效果 |
|---|---|
| 左键点击图标 | 开启 / 关闭常亮 |
| 右键点击图标 | 弹出菜单：状态、开关、开启时长、开机自启、退出 |
| 选择开启时长 | 立即保存；已开启时按新时长重新倒计时 |
| 退出 | 释放断言并恢复系统设置（保留偏好，供下次启动恢复） |

## 实现原理

核心使用 IOKit 电源断言，而非修改系统设置：

- 开启时创建 `kIOPMAssertionTypePreventUserIdleDisplaySleep`（阻止显示器关闭与屏保）和 `kIOPMAssertionTypeNoIdleSleep`（阻止系统空闲休眠）两个断言
- 关闭时调用 `IOPMAssertionRelease` 释放，系统策略立即恢复原状
- 断言按进程归属，App 崩溃或强制退出时系统自动回收，不会遗留状态

定时功能记录绝对到期时间戳并持久化到 `UserDefaults`，每秒刷新剩余时间；到期自动释放断言。重启时若未过期则继续倒计时，已过期则保持关闭。

### 已知边界

合盖休眠（MacBook 合上盖子）与用户主动锁屏（`Ctrl+Cmd+Q`）不受影响，这两类属于硬件策略/主动操作，电源断言无法覆盖。

## 工程结构

```
NoSleepBar/
├── Package.swift                        SwiftPM 工程定义
├── build.sh                             构建、打包、签名脚本
├── gen_icon.swift                       App 图标生成脚本（AppKit 绘制）
├── Resources/
│   ├── Info.plist                       App 配置（LSUIElement、图标引用等）
│   └── AppIcon.icns                     App 图标（16~1024 多尺寸）
└── Sources/NoSleepBar/
    ├── main.swift                       入口，启动 NSApplication
    ├── AppDelegate.swift                生命周期与状态恢复
    ├── StatusBarController.swift        菜单栏图标、菜单、定时倒计时与 UI
    ├── PowerAssertionManager.swift      IOKit 电源断言创建与释放
    ├── Preferences.swift                UserDefaults 偏好与时长枚举
    └── LoginItemManager.swift           开机自启（LaunchAgent）
```

## 构建与安装

环境要求：macOS 11+，Xcode 命令行工具（Swift 5.9+）。

```bash
cd /Users/xinbaojian/workspace/apple/NoSleepBar
./build.sh                         # 编译并生成 NoSleepBar.app（含 ad-hoc 签名）
cp -R NoSleepBar.app /Applications/ # 安装到本机
open /Applications/NoSleepBar.app  # 启动
```

说明：构建脚本使用 `swift build --disable-sandbox`（本环境下 SwiftPM 沙箱受限），打包后执行 ad-hoc 签名。

如需重新生成图标：

```bash
swift gen_icon.swift                                    # 生成 /tmp/nosleepbar_icon_1024.png
# 再用 sips 生成各尺寸 iconset，iconutil -c icns 输出 Resources/AppIcon.icns
```

## 验证方式

```bash
# 开启后查看断言（应看到 NoSleepBar 持有的两个断言）
pmset -g assertions | grep -i NoSleepBar

# 关闭或到期后确认断言已释放、系统恢复默认
pmset -g assertions | grep -i "PreventUserIdleDisplaySleep"
```

偏好数据存储在 `com.nosleepbar.app` 域，可用 `defaults read com.nosleepbar.app` 查看。
