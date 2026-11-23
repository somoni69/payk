import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let referralChannelName = "app.payk.payk/referral"

  private var referralChannel: FlutterMethodChannel?
  private var initialReferralLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: Self.referralChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    referralChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "getInstallReferrer":
        result(nil)
      case "getInitialLink":
        result(self.initialReferralLink)
      case "getDeviceInfo":
        result(self.collectDeviceInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func handleIncomingReferralURL(_ url: URL) {
    let raw = url.absoluteString
    initialReferralLink = raw
    referralChannel?.invokeMethod("onLink", arguments: raw)
  }

  private func collectDeviceInfo() -> [String: Any] {
    // model на iOS намеренно не отправляем (docs/loyalty-referral-deeplink.md):
    // Safari не раскрывает модель, поэтому на сервере iPhone сверяется по ОС, языку, экрану и поясу.
    let bounds = UIScreen.main.bounds
    let shortSide = Int(round(min(bounds.width, bounds.height)))
    let longSide = Int(round(max(bounds.width, bounds.height)))
    let scale = UIScreen.main.scale
    let scaleText = scale.truncatingRemainder(dividingBy: 1) == 0
      ? String(Int(scale))
      : String(format: "%.2f", scale)
          .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
          .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)

    var info: [String: Any] = [
      "platform": "ios",
      "os_version": UIDevice.current.systemVersion,
      "timezone": TimeZone.current.identifier,
    ]
    if shortSide > 0 && longSide > 0 {
      info["screen"] = "\(shortSide)x\(longSide)x\(scaleText)"
    }
    if let lang = Locale.preferredLanguages.first, !lang.isEmpty {
      info["language"] = lang
    }
    return info
  }
}
