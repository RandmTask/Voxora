import Foundation

struct EmailDraft: Identifiable {
  var id = UUID()
  var subject: String
  var body: String
}
