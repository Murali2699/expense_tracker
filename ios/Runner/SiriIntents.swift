import AppIntents
import Foundation
import Security
import UIKit

@available(iOS 16.0, *)
private enum SiriApiHelper {
  static func apiBaseUrl() -> String {
    if let path = Bundle.main.path(forResource: ".env", ofType: nil, inDirectory: "flutter_assets"),
       let content = try? String(contentsOfFile: path, encoding: .utf8) {
      for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("API_BASE_URL=") {
          let val = String(trimmed.dropFirst("API_BASE_URL=".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
          return val.hasSuffix("/") ? String(val.dropLast()) : val
        }
      }
    }
    return "https://expensetrack.muralikrishnan.in"
  }

  static func readKeychain(_ key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "flutter_secure_storage_service",
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func saveKeychain(_ key: String, value: String) {
    guard let data = value.data(using: .utf8) else { return }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "flutter_secure_storage_service",
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
    var add = query
    add[kSecValueData as String] = data
    SecItemAdd(add as CFDictionary, nil)
  }

  static func refreshAccessToken() async -> String? {
    guard let refresh = readKeychain("refresh_token"),
          let url = URL(string: "\(apiBaseUrl())/api/v1/auth/refresh") else {
      return nil
    }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refresh])
    req.timeoutInterval = 12

    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          let http = resp as? HTTPURLResponse, http.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let newAccess = json["accessToken"] as? String,
          let newRefresh = json["refreshToken"] as? String else {
      return nil
    }
    saveKeychain("access_token", value: newAccess)
    saveKeychain("refresh_token", value: newRefresh)
    return newAccess
  }

  static func request(
    path: String,
    method: String = "GET",
    body: [String: Any]? = nil
  ) async -> (Int, [String: Any])? {
    guard var token = readKeychain("access_token"),
          let url = URL(string: "\(apiBaseUrl())\(path)") else {
      return nil
    }

    func send(_ bearer: String) async -> (Int, [String: Any])? {
      var req = URLRequest(url: url)
      req.httpMethod = method
      req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
      req.timeoutInterval = 12
      if let body = body {
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
      }
      guard let (data, resp) = try? await URLSession.shared.data(for: req),
            let http = resp as? HTTPURLResponse else {
        return nil
      }
      let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
      return (http.statusCode, json)
    }

    guard let first = await send(token) else { return nil }
    if first.0 == 401, let newToken = await refreshAccessToken() {
      token = newToken
      return await send(token)
    }
    return first
  }
}

@available(iOS 16.0, *)
struct AddExpenseIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Expense"
  static var description = IntentDescription("Add an expense to Expense Tracker.")

  @Parameter(title: "Amount")
  var amount: Double

  @Parameter(title: "Category")
  var category: String

  @Parameter(title: "Date")
  var expenseDate: Date?

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    let dateStr = df.string(from: expenseDate ?? Date())

    let body: [String: Any] = [
      "expenseDate": dateStr,
      "category": category.trimmingCharacters(in: .whitespacesAndNewlines),
      "amount": amount,
      "note": "Added via Siri",
    ]

    guard let (status, json) = await SiriApiHelper.request(
      path: "/api/v1/expenses",
      method: "POST",
      body: body
    ) else {
      return .result(dialog: "Please open Expense Tracker and sign in first.")
    }

    if status == 201 {
      return .result(dialog: "Added ₹\(String(format: "%.2f", amount)) in \(category) for \(dateStr).")
    }
    let err = (json["error"] as? String) ?? "Failed to add expense."
    return .result(dialog: IntentDialog(stringLiteral: err))
  }
}

@available(iOS 16.0, *)
struct SendReminderIntent: AppIntent {
  static var title: LocalizedStringResource = "Send WhatsApp Reminder"
  static var description = IntentDescription("Send a pending payment reminder in WhatsApp.")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Person Name")
  var personName: String

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let (status, json) = await SiriApiHelper.request(
      path: "/api/v1/lent?status=PENDING",
      method: "GET"
    ) else {
      return .result(dialog: "Please open Expense Tracker and sign in first.")
    }

    if status != 200 {
      return .result(dialog: "Could not fetch pending records.")
    }

    let groups = (json["groups"] as? [[String: Any]]) ?? []
    let needle = personName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard let match = groups.first(where: {
      (($0["personName"] as? String) ?? "").lowercased().contains(needle)
    }),
    let phone = match["phoneNumber"] as? String else {
      return .result(dialog: "No pending I Gave record found for \(personName).")
    }

    guard let (remStatus, remJson) = await SiriApiHelper.request(
      path: "/api/v1/lent/remind",
      method: "POST",
      body: ["phoneNumber": phone]
    ), remStatus == 200 else {
      return .result(dialog: "Failed to prepare WhatsApp reminder.")
    }

    if (remJson["mode"] as? String) == "cloud_api",
       (remJson["sent"] as? Bool) == true {
      return .result(dialog: "WhatsApp reminder sent to \(personName).")
    }

    let message = (remJson["message"] as? String) ?? ""
    let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    if let waUrl = URL(string: "https://wa.me/\(phone)?text=\(encoded)") {
      await MainActor.run {
        UIApplication.shared.open(waUrl)
      }
      return .result(dialog: "Opening WhatsApp reminder for \(personName).")
    }
    return .result(dialog: "Could not open WhatsApp.")
  }
}

@available(iOS 16.0, *)
struct ExpenseAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddExpenseIntent(),
      phrases: [
        "Add expense in \(.applicationName)",
        "Log expense in \(.applicationName)",
      ]
    )
    AppShortcut(
      intent: SendReminderIntent(),
      phrases: [
        "Send reminder in \(.applicationName)",
        "Send WhatsApp reminder in \(.applicationName)",
      ]
    )
  }
}
