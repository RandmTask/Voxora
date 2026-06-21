import Foundation

struct GeminiClient {
  func generate(prompt: String, apiKey: String) async throws -> String {
    guard !apiKey.isEmpty else {
      throw VoxoraAPIError.missingAPIKey(.gemini)
    }

    let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    guard let url = URL(string: endpoint) else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    request.httpBody = try JSONEncoder().encode(
      GeminiGenerateRequest(
        contents: [
          GeminiContent(parts: [GeminiPart(text: prompt)])
        ]
      )
    )

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          200 ..< 300 ~= httpResponse.statusCode else {
      throw URLError(.badServerResponse)
    }

    let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
    let text = decoded.candidates
      .flatMap(\.content.parts)
      .compactMap(\.text)
      .joined(separator: "\n")

    guard !text.isEmpty else {
      throw VoxoraAPIError.malformedResponse
    }

    return text
  }
}

private struct GeminiGenerateRequest: Encodable {
  var contents: [GeminiContent]
}

private struct GeminiContent: Encodable, Decodable {
  var parts: [GeminiPart]
}

private struct GeminiPart: Encodable, Decodable {
  var text: String?
}

private struct GeminiGenerateResponse: Decodable {
  var candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
  var content: GeminiContent
}
