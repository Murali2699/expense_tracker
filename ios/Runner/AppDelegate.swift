import ContactsUI
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CNContactPickerDelegate {
  private var pendingContactResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 16.0, *) {
      ExpenseAppShortcuts.updateAppShortcutParameters()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let clipboardChannel = FlutterMethodChannel(
      name: "in.muralikrishnan.expense_tracker/clipboard",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    clipboardChannel.setMethodCallHandler { call, result in
      if call.method == "copyImage",
         let args = call.arguments as? [String: Any],
         let path = args["path"] as? String,
         let image = UIImage(contentsOfFile: path) {
        UIPasteboard.general.image = image
        result(true)
      } else {
        result(false)
      }
    }

    let channel = FlutterMethodChannel(
      name: "in.muralikrishnan.expense_tracker/contacts",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "pickContact" {
        DispatchQueue.main.async {
          self.pendingContactResult = result
          let picker = CNContactPickerViewController()
          picker.delegate = self
          picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
          if let rootVC = self.topViewController() {
            rootVC.present(picker, animated: true, completion: nil)
          } else {
            self.pendingContactResult = nil
            result(nil)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow }) ?? scenes.first?.windows.first
    var vc = window?.rootViewController
    while let presented = vc?.presentedViewController {
      vc = presented
    }
    return vc
  }

  func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
    let name = [contact.givenName, contact.familyName]
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
    pendingContactResult?(["name": name, "phone": phone])
    pendingContactResult = nil
  }

  func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
    pendingContactResult?(nil)
    pendingContactResult = nil
  }
}
