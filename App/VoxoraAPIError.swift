import Foundation

enum VoxoraAPIError: LocalizedError {
  case missingAPIKey(AIProvider)
  case unavailableProvider(AIProvider)
  case malformedResponse
  case mailUnavailable

  var errorDescription: String? {
    switch self {
    case .missingAPIKey(let provider):
      "\(provider.title) key is missing."
    case .unavailableProvider(let provider):
      "\(provider.title) is unavailable on this device."
    case .malformedResponse:
      "The provider response could not be parsed."
    case .mailUnavailable:
      "Mail is not configured on this device."
    }
  }
}
