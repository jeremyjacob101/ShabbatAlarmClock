import Foundation
import UserNotifications

final class AlarmNotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlarmNotificationPresentationDelegate()

    private override init() { }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
