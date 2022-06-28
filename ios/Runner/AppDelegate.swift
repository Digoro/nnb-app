import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "NNB/INTENT", binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
      guard call.method == "intent" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let args = call.arguments as? Dictionary<String, Any>,
        let url = args["url"] as? String {
        if let openApp = URL(string: url), UIApplication.shared.canOpenURL(openApp) {
             if #available(iOS 10.0, *) {
                 UIApplication.shared.open(openApp, options: [:], completionHandler: nil)
             }
             else {
                 UIApplication.shared.openURL(openApp)
             }
         }
      } else {
        result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
      }
    })
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

