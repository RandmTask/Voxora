import Foundation

struct OpenAIClient {
  func generate(prompt: String, apiKey: String) async throws -> String {
    guard !apiKey.isEmpty else { throw VoxoraAPIError.missingAPIKey(.openAI) }
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(OpenAIRequest(model: "gpt-4.1-mini", input: prompt))
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw URLError(.badServerResponse)
    }
    let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
    let text = decoded.output.flatMap(\.content).compactMap(\.text).joined(separator: "\n")
    guard !text.isEmpty else { throw VoxoraAPIError.malformedResponse }
    return text
  }
}

private struct OpenAIRequest: Encodable {
  let model: String
  let input: String
}

private struct OpenAIResponse: Decodable {
  let output: [OpenAIOutput]
}

private struct OpenAIOutput: Decodable {
  let content: [OpenAIContent]
}

private struct OpenAIContent: Decodable {
  let text: String?
}
