import Foundation

/// 通过用户级 LaunchAgent 实现开机自启。
/// plist 写入 ~/Library/LaunchAgents，仅对当前用户生效，无需管理员权限。
final class LoginItemManager {
    static let shared = LoginItemManager()

    private let label = "com.nosleepbar.agent"
    private var plistURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private init() {}

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// 开启或关闭开机自启。
    /// - Parameter enabled: true 表示登录时自动启动。
    func setEnabled(_ enabled: Bool) {
        if enabled {
            install()
        } else {
            uninstall()
        }
        Preferences.shared.autoLaunch = enabled
    }

    private func install() {
        let bundlePath = Bundle.main.bundleURL.path
        // 仅在打包为 .app 后可自启；直接用可执行文件运行时无法定位 bundle。
        guard bundlePath.hasSuffix(".app") else {
            NSLog("NoSleepBar: 未以 .app 形式运行，跳过开机自启安装")
            return
        }

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/open</string>
                <string>\(bundlePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """

        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            bootstrap()
        } catch {
            NSLog("NoSleepBar: 安装 LaunchAgent 失败: \(error.localizedDescription)")
        }
    }

    private func uninstall() {
        bootout()
        try? FileManager.default.removeItem(at: plistURL)
    }

    private var bootstrapDomain: String {
        "gui/\(getuid())"
    }

    private func bootstrap() {
        // 先尝试卸载可能已存在的旧服务，避免重复 bootstrap 报错（未加载时该调用无害）。
        bootout()
        runLaunchctl("bootstrap", bootstrapDomain, plistURL.path)
    }

    private func bootout() {
        runLaunchctl("bootout", bootstrapDomain, plistURL.path)
    }

    private func runLaunchctl(_ arguments: String...) {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = arguments
        let pipe = Pipe()
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            NSLog("NoSleepBar: launchctl 调用失败: \(error.localizedDescription)")
        }
    }
}
