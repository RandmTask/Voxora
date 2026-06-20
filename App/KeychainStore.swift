import Foundation
import Security

final class KeychainStore {
  private let service = "VoiceSynapse"

  func value(for key: String) -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess,
          let data = item as? Data,
          let value = String(data: data, encoding: .utf8) else {
      return ""
    }

    return value
  }

  func save(_ value: String, for key: String) {
    let encodedValue = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]

    let attributes: [String: Any] = [
      kSecValueData as String: encodedValue
    ]

    if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
      SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    } else {
      var newItem = query
      newItem[kSecValueData as String] = encodedValue
      SecItemAdd(newItem as CFDictionary, nil)
    }
  }
}
