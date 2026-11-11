import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var screenSecure = false
  private var cover: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(hideCashierCode),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(showCashierCode),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "app.payk.payk/screen",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setSecure" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.screenSecure = (call.arguments as? Bool) ?? false
      if self?.screenSecure != true {
        self?.removeCover()
      } else if UIScreen.main.isCaptured {
        self?.addCover()
      }
      result(nil)
    }
  }

  @objc private func hideCashierCode() {
    if screenSecure { addCover() }
  }

  @objc private func showCashierCode() {
    if !UIScreen.main.isCaptured { removeCover() }
  }

  @objc private func captureChanged() {
    if screenSecure && UIScreen.main.isCaptured {
      addCover()
    } else if !UIScreen.main.isCaptured {
      removeCover()
    }
  }

  private func addCover() {
    guard cover == nil, let window = keyWindow else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    cover = blur
  }

  private func removeCover() {
    cover?.removeFromSuperview()
    cover = nil
  }

  private var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }
}
