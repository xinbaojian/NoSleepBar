import AppKit

/// 菜单栏图标与右键菜单控制器，含定时自动关闭。
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let power = PowerAssertionManager.shared

    private let statusMenuItem = NSMenuItem(title: "状态：已关闭", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "开启常亮", action: #selector(toggle), keyEquivalent: "")
    private let durationMenuItem = NSMenuItem(title: "开启时长", action: nil, keyEquivalent: "")
    private let durationSubmenu = NSMenu()
    private let autoLaunchMenuItem = NSMenuItem(title: "开机自启", action: #selector(toggleAutoLaunch), keyEquivalent: "")
    private let quitMenuItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")

    // 倒计时：到期绝对时间（Unix 时间戳）与定时器。
    private var expiryTimestamp: TimeInterval = 0
    private var countdownTimer: Timer?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupMenu()
        setupStatusItem()
        refresh()
    }

    deinit {
        countdownTimer?.invalidate()
    }

    // MARK: - 初始化

    /// 根据状态生成菜单栏图标：关闭为 moon，开启为 sun.max.fill。
    private func icon(isOn: Bool) -> NSImage? {
        let name = isOn ? "sun.max.fill" : "moon"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = icon(isOn: false)
        // 同时接收左右键，在 action 中区分处理。
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupMenu() {
        menu.delegate = self

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        // 时长子菜单
        for option in DurationOption.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectDuration(_:)), keyEquivalent: "")
            item.target = self
            item.tag = option.rawValue
            item.state = option.rawValue == Preferences.shared.durationSeconds ? .on : .off
            durationSubmenu.addItem(item)
        }
        durationMenuItem.submenu = durationSubmenu
        menu.addItem(durationMenuItem)

        autoLaunchMenuItem.target = self
        menu.addItem(autoLaunchMenuItem)
        menu.addItem(NSMenuItem.separator())

        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
    }

    // MARK: - 交互

    /// 左键点击直接切换，右键点击弹出菜单。
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let eventType = NSApp.currentEvent?.type
        if eventType == .rightMouseUp {
            let point = NSPoint(x: 0, y: sender.bounds.height)
            menu.popUp(positioning: nil, at: point, in: sender)
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        if power.isEnabled {
            turnOff()
        } else {
            if power.enable() {
                Preferences.shared.isEnabled = true
                startCountdown(seconds: Preferences.shared.durationSeconds)
            }
        }
        refresh()
    }

    /// 选择时长：立即更新菜单勾选；若已开启则按新时长重新计时。
    @objc private func selectDuration(_ sender: NSMenuItem) {
        let seconds = sender.tag
        Preferences.shared.durationSeconds = seconds
        if power.isEnabled {
            startCountdown(seconds: seconds)
        }
        refresh()
    }

    @objc private func toggleAutoLaunch() {
        let newValue = !LoginItemManager.shared.isEnabled
        LoginItemManager.shared.setEnabled(newValue)
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - 定时逻辑

    /// 按给定时长启动/重启倒计时。seconds = 0 表示不限时，清除倒计时。
    private func startCountdown(seconds: Int) {
        countdownTimer?.invalidate()
        countdownTimer = nil

        guard seconds > 0 else {
            expiryTimestamp = 0
            Preferences.shared.expiryTimestamp = 0
            return
        }

        let expiry = Date().timeIntervalSince1970 + TimeInterval(seconds)
        expiryTimestamp = expiry
        Preferences.shared.expiryTimestamp = expiry

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    /// 每秒检查是否到期，并刷新菜单栏剩余时间。
    @objc private func tick() {
        guard power.isEnabled, expiryTimestamp > 0 else { return }
        let remaining = Int(expiryTimestamp - Date().timeIntervalSince1970)
        if remaining <= 0 {
            turnOff()
            refresh()
        } else {
            updateRemainingUI(remaining)
        }
    }

    /// 关闭常亮：释放断言、清除倒计时并落盘。
    private func turnOff() {
        power.disable()
        Preferences.shared.isEnabled = false
        countdownTimer?.invalidate()
        countdownTimer = nil
        expiryTimestamp = 0
        Preferences.shared.expiryTimestamp = 0
    }

    /// 由 AppDelegate 在启动时调用：若上次处于开启态，恢复断言与剩余倒计时。
    func applyInitialState() {
        guard Preferences.shared.isEnabled else {
            refresh()
            return
        }

        let savedExpiry = Preferences.shared.expiryTimestamp
        // 若存在倒计时且已过期，则保持关闭并清理状态。
        if savedExpiry > 0 && savedExpiry <= Date().timeIntervalSince1970 {
            Preferences.shared.isEnabled = false
            Preferences.shared.expiryTimestamp = 0
            refresh()
            return
        }

        if power.enable() {
            if savedExpiry > 0 {
                expiryTimestamp = savedExpiry
                startCountdownWithExpiry(savedExpiry)
            }
        }
        refresh()
    }

    /// 使用已有的到期时间戳恢复倒计时（重启场景）。
    private func startCountdownWithExpiry(_ expiry: TimeInterval) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        expiryTimestamp = expiry
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    /// 退出时释放断言，但保留开关偏好与到期时间，供开机自启后恢复剩余时长。
    func releaseOnQuit() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        power.disable()
    }

    // MARK: - UI 刷新

    /// 刷新图标、菜单文案与时长勾选，UI 与断言状态同源。
    func refresh() {
        let isOn = power.isEnabled

        if let button = statusItem.button {
            button.image = icon(isOn: isOn)
            if isOn && expiryTimestamp > 0 {
                let remaining = max(0, Int(expiryTimestamp - Date().timeIntervalSince1970))
                button.attributedTitle = remainingTitle(remaining)
                button.toolTip = "常亮已开启 · 剩余 \(formatDuration(remaining)) · 右键管理"
            } else {
                button.attributedTitle = NSAttributedString(string: "")
                button.toolTip = isOn ? "常亮已开启 · 不限时 · 右键管理" : "常亮已关闭 · 点击开启"
            }
        }

        if isOn && expiryTimestamp > 0 {
            let remaining = max(0, Int(expiryTimestamp - Date().timeIntervalSince1970))
            statusMenuItem.title = "状态：已开启 · 剩余 \(formatDuration(remaining))"
        } else {
            statusMenuItem.title = isOn ? "状态：已开启（不限时）" : "状态：已关闭（系统默认）"
        }

        toggleMenuItem.title = isOn ? "关闭常亮" : "开启常亮"

        let currentDuration = Preferences.shared.durationSeconds
        for item in durationSubmenu.items {
            item.state = item.tag == currentDuration ? .on : .off
        }

        autoLaunchMenuItem.state = LoginItemManager.shared.isEnabled ? .on : .off
    }

    /// 仅更新菜单栏与状态项的剩余时间（每秒调用，避免重建整个菜单）。
    private func updateRemainingUI(_ remaining: Int) {
        if let button = statusItem.button {
            button.attributedTitle = remainingTitle(remaining)
            button.toolTip = "常亮已开启 · 剩余 \(formatDuration(remaining)) · 右键管理"
        }
        statusMenuItem.title = "状态：已开启 · 剩余 \(formatDuration(remaining))"
    }

    /// 菜单栏剩余时间文字，使用小字号并带前导空格与图标分隔。
    private func remainingTitle(_ remaining: Int) -> NSAttributedString {
        NSAttributedString(
            string: " \(formatDuration(remaining))",
            attributes: [.font: NSFont.menuBarFont(ofSize: 0), .foregroundColor: NSColor.controlTextColor]
        )
    }

    /// 将秒数格式化为 X小时X分 / X分X秒 / X秒。
    private func formatDuration(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        if seconds >= 3600 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return m > 0 ? "\(h)小时\(m)分" : "\(h)小时"
        }
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)分\(s)秒" : "\(m)分"
        }
        return "\(seconds)秒"
    }
}
