import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.enzily.app/game_notifications",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "requestPermission":
          self.requestNotificationPermission(result)
        case "show":
          self.showNotification(args: args, result: result)
        case "schedule":
          self.scheduleNotification(args: args, result: result)
        case "cancel":
          self.cancelNotification(args: args, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func requestNotificationPermission(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
      result(true)
    }
  }

  private func showNotification(args: [String: Any], result: @escaping FlutterResult) {
    requestNotificationPermission { _ in
      let content = self.notificationContent(args: args)
      let id = self.notificationId(args: args, fallback: "inzeli-game-now")
      let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
      UNUserNotificationCenter.current().add(request) { _ in result(true) }
    }
  }

  private func scheduleNotification(args: [String: Any], result: @escaping FlutterResult) {
    requestNotificationPermission { _ in
      let content = self.notificationContent(args: args)
      let id = self.notificationId(args: args, fallback: "inzeli-game-end")
      let seconds = max(1, self.number(args["delaySeconds"])?.doubleValue ?? 1)
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
      let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
      UNUserNotificationCenter.current().add(request) { _ in result(true) }
    }
  }

  private func cancelNotification(args: [String: Any], result: @escaping FlutterResult) {
    let id = notificationId(args: args, fallback: "inzeli-game-end")
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    result(true)
  }

  private func notificationContent(args: [String: Any]) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = args["title"] as? String ?? "إنزلي"
    content.body = args["body"] as? String ?? ""
    content.sound = .default
    content.categoryIdentifier = "INZELI_GAME_TIMER"
    return content
  }

  private func notificationId(args: [String: Any], fallback: String) -> String {
    if let id = number(args["id"]) {
      return "inzeli-\(id.intValue)"
    }
    return fallback
  }

  private func number(_ value: Any?) -> NSNumber? {
    if let number = value as? NSNumber { return number }
    if let int = value as? Int { return NSNumber(value: int) }
    if let double = value as? Double { return NSNumber(value: double) }
    if let string = value as? String, let double = Double(string) {
      return NSNumber(value: double)
    }
    return nil
  }
}
