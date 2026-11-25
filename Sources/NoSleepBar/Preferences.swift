import Foundation

/// 可选的保持唤醒时长。rawValue 为秒数，0 表示不限时。
enum DurationOption: Int, CaseIterable {
    case unlimited = 0
    case minutes15 = 900
    case minutes30 = 1800
    case hour1 = 3600
    case hour2 = 7200
    case hour4 = 14400
    case hour8 = 28800

    var title: String {
        switch self {
        case .unlimited: return "不限时"
        case .minutes15: return "15 分钟"
        case .minutes30: return "30 分钟"
        case .hour1: return "1 小时"
        case .hour2: return "2 小时"
        case .hour4: return "4 小时"
        case .hour8: return "8 小时"
        }
    }

    init(seconds: Int) {
        self = DurationOption(rawValue: seconds) ?? .unlimited
    }
}

/// 使用 UserDefaults 持久化开关状态、时长偏好与到期时间。
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard
    private let enabledKey = "NoSleepBar.isEnabled"
    private let autoLaunchKey = "NoSleepBar.autoLaunch"
    private let durationKey = "NoSleepBar.durationSeconds"
    private let expiryKey = "NoSleepBar.expiryTimestamp"

    private init() {}

    var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    var autoLaunch: Bool {
        get { defaults.bool(forKey: autoLaunchKey) }
        set { defaults.set(newValue, forKey: autoLaunchKey) }
    }

    /// 当前设定的时长（秒），0 表示不限时。
    var durationSeconds: Int {
        get { defaults.object(forKey: durationKey) as? Int ?? 0 }
        set { defaults.set(newValue, forKey: durationKey) }
    }

    /// 当前倒计时到期时间戳（Unix 时间），0 表示无倒计时。
    var expiryTimestamp: TimeInterval {
        get { defaults.double(forKey: expiryKey) }
        set { defaults.set(newValue, forKey: expiryKey) }
    }
}
