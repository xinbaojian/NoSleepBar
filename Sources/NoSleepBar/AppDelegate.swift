import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏常驻 App：不显示 Dock 图标，不激活为前台应用。
        NSApp.setActivationPolicy(.accessory)

        statusBarController = StatusBarController()
        statusBarController?.applyInitialState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 兜底释放断言，避免极端情况下残留。
        statusBarController?.releaseOnQuit()
    }
}
