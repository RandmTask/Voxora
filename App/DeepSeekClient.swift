import Foundation

struct DeepSeekClient {
  func generate(prompt: String, apiKey: String) async throws -> String {
    guard !apiKey.isEmpty else {
      throw VoxoraAPIError.missingAPIKey(.deepSeek)
    }

    guard let url = URL(string: "https://api.deepseek.com/chat/completions") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(
      DeepSeekRequest(
        model: "deepseek-chat",
        messages: [
          DeepSeekMessage(role: "user", content: prompt)
        ]
      )
    )

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          200 ..< 300 ~= httpResponse.statusCode else {
      throw URLError(.badServerResponse)
    }

    let decoded = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
    guard let text = decoded.choices.first?.message.content,
          !text.isEmpty else {
      throw VoxoraAPIError.malformedResponse
    }

    return text
  }
}

private struct DeepSeekRequest: Encodable {
  var model: String
  var messages: [DeepSeekMessage]
}

private struct DeepSeekMessage: Codable {
  var role: String
  var content: String
}

private struct DeepSeekResponse: Decodable {
  var choices: [DeepSeekChoice]
}

private struct DeepSeekChoice: Decodable {
  var message: DeepSeekMessage
}
