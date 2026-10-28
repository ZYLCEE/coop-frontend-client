import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let privacyOverlayTag = 9137

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    guard let window = window else { return }
    let privacyOverlay = UIView(frame: window.bounds)
    privacyOverlay.backgroundColor = UIColor(red: 0.10, green: 0.37, blue: 0.22, alpha: 1)
    privacyOverlay.tag = privacyOverlayTag
    window.addSubview(privacyOverlay)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    window?.viewWithTag(privacyOverlayTag)?.removeFromSuperview()
  }
}
