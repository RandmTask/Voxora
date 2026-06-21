import Foundation

struct CloudAudioTranscriber {
  func transcribe(
    audioURL: URL,
    engine: TranscriptionEngine,
    apiKey: String
  ) async throws -> String {
    guard !apiKey.isEmpty else {
      let provider: AIProvider = engine == .gemini ? .gemini : .openAI
      throw VoxoraAPIError.missingAPIKey(provider)
    }

    switch engine {
    case .appleSpeech:
      throw VoxoraAPIError.unavailableProvider(.appleIntelligence)
    case .gemini:
      return try await transcribeWithGemini(audioURL: audioURL, apiKey: apiKey)
    case .openAI:
      return try await transcribeWithOpenAI(audioURL: audioURL, apiKey: apiKey)
    }
  }

  private func transcribeWithGemini(audioURL: URL, apiKey: String) async throws -> String {
    let audioData = try Data(contentsOf: audioURL)
    let mimeType = audioURL.pathExtension.lowercased() == "caf" ? "audio/x-caf" : "audio/mp4"
    var request = URLRequest(
      url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!
    )
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "contents": [[
        "parts": [
          ["text": "Transcribe this voice note verbatim. Return only the transcript."],
          ["inline_data": ["mime_type": mimeType, "data": audioData.base64EncodedString()]]
        ]
      ]]
    ])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw URLError(.badServerResponse)
    }
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let candidates = object?["candidates"] as? [[String: Any]]
    let content = candidates?.first?["content"] as? [String: Any]
    let parts = content?["parts"] as? [[String: Any]]
    let text = parts?.compactMap { $0["text"] as? String }.joined(separator: "\n") ?? ""
    guard !text.isEmpty else { throw VoxoraAPIError.malformedResponse }
    return text
  }

  private func transcribeWithOpenAI(audioURL: URL, apiKey: String) async throws -> String {
    let boundary = "Voxora-\(UUID().uuidString)"
    let audioData = try Data(contentsOf: audioURL)
    var body = Data()
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\ngpt-4o-mini-transcribe\r\n")
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n")
    body.append("Content-Type: application/octet-stream\r\n\r\n")
    body.append(audioData)
    body.append("\r\n--\(boundary)--\r\n")

    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
      throw URLError(.badServerResponse)
    }
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let text = object?["text"] as? String, !text.isEmpty else {
      throw VoxoraAPIError.malformedResponse
    }
    return text
  }
}

private extension Data {
  mutating func append(_ string: String) {
    append(Data(string.utf8))
  }
}
