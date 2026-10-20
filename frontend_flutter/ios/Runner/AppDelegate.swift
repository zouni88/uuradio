import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pathMonitor = NWPathMonitor()
  private var netType = "none"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    setupSignalChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// iOS 无公开 API 读取 WiFi/蜂窝场强（RSSI），仅提供网络类型，
  /// rssi/level 由 Dart 侧按不可测降级展示。
  private func setupSignalChannel() {
    pathMonitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      if path.status != .satisfied {
        self.netType = "none"
      } else if path.usesInterfaceType(.cellular) {
        self.netType = "cell"
      } else {
        // wifi / ethernet / 其他有线接入统一归为 wifi
        self.netType = "wifi"
      }
    }
    pathMonitor.start(queue: DispatchQueue.global(qos: .utility))

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "iradio/signal",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getSignal":
        guard let self else {
          result(["type": "none", "level": 0])
          return
        }
        result(["type": self.netType, "level": 0])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
