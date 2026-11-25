import Foundation
import IOKit.pwr_mgt

/// 管理 IOKit 电源断言：开启时阻止显示器关闭与系统空闲休眠，关闭时释放断言恢复系统原设置。
final class PowerAssertionManager {
    static let shared = PowerAssertionManager()

    private var assertionIDs: [IOPMAssertionID] = []
    private let lock = NSLock()

    private init() {}

    /// 当前是否处于“保持唤醒”状态。
    var isEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !assertionIDs.isEmpty
    }

    /// 创建电源断言。重复调用是幂等的。
    /// - Returns: 是否成功创建全部断言。
    @discardableResult
    func enable() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard assertionIDs.isEmpty else { return true }

        var newIDs: [IOPMAssertionID] = []
        let reasons: [(String, String)] = [
            (kIOPMAssertionTypePreventUserIdleDisplaySleep, "NoSleepBar: prevent display sleep"),
            (kIOPMAssertionTypeNoIdleSleep, "NoSleepBar: prevent idle sleep")
        ]

        for (type, reason) in reasons {
            var assertionID: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type as CFString,
                IOOptionBits(kIOPMAssertionLevelOn),
                reason as CFString,
                &assertionID
            )
            if result == kIOReturnSuccess {
                newIDs.append(assertionID)
            } else {
                NSLog("NoSleepBar: 创建断言失败, code=\(result)")
            }
        }

        if newIDs.isEmpty {
            return false
        }
        assertionIDs = newIDs
        return true
    }

    /// 释放全部断言，系统策略立即恢复原状。重复调用是幂等的。
    func disable() {
        lock.lock()
        defer { lock.unlock() }

        for id in assertionIDs {
            let result = IOPMAssertionRelease(id)
            if result != kIOReturnSuccess {
                NSLog("NoSleepBar: 释放断言失败, code=\(result)")
            }
        }
        assertionIDs.removeAll()
    }
}
