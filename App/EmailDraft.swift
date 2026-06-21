import Foundation

struct EmailAttachment {
  var data: Data
  var mimeType: String
  var fileName: String
}

struct EmailDraft: Identifiable {
  var id = UUID()
  var recipients: [String] = []
  var ccRecipients: [String] = []
  var bccRecipients: [String] = []
  var subject: String
  var body: String
  var attachments: [EmailAttachment] = []
}
