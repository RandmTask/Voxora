import Foundation

struct EmailDraft: Identifiable {
  var id = UUID()
  var recipients: [String] = []
  var ccRecipients: [String] = []
  var subject: String
  var body: String
}
