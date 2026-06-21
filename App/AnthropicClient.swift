import Foundation

struct AnthropicClient {
  func generate(prompt: String, apiKey: String) async throws -> String {
    guard !apiKey.isEmpty else { throw VoxoraAPIError.missingAPIKey(.anthropic) }
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.httpBody = try JSONEncoder().encode(
      AnthropicRequest(
        model: "claude-sonnet-4-5",
        maxTokens: 1_024,
        messages: [AnthropicMessage(role: "user", content: prompt)]
      )
    )
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw URLError(.badServerResponse)
    }
    let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
    let text = decoded.content.compactMap(\.text).joined(separator: "\n")
    guard !text.isEmpty else { throw VoxoraAPIError.malformedResponse }
    return text
  }
}

private struct AnthropicRequest: Encodable {
  let model: String
  let maxTokens: Int
  let messages: [AnthropicMessage]

  enum CodingKeys: String, CodingKey {
    case model, messages
    case maxTokens = "max_tokens"
  }
}

private struct AnthropicMessage: Codable {
  let role: String
  let content: String
}

private struct AnthropicResponse: Decodable {
  let content: [AnthropicContent]
}

private struct AnthropicContent: Decodable {
  let text: String?
}
