import Foundation

struct LLMRequest {
    var provider: AIProvider
    var model: String
    var system: String
    var user: String
    var openAIKey: String
    var anthropicKey: String
    var reasoning: String
    var maxOutputTokens: Int
    var timeoutSeconds: TimeInterval = 180
}

struct LLMClient {
    func complete(_ request: LLMRequest) async throws -> String {
        do {
            switch request.provider {
            case .openAI:
                return try await callOpenAI(request)
            case .anthropic:
                return try await callAnthropic(request)
            }
        } catch let error as URLError {
            throw RunnerError.apiError(networkMessage(for: error, provider: request.provider))
        }
    }

    private func callOpenAI(_ request: LLMRequest) async throws -> String {
        let key = request.openAIKey.trimmed
        guard !key.isEmpty else { throw RunnerError.missingAPIKey("OpenAI API Key fehlt.") }

        var payload: [String: Any] = [
            "model": request.model,
            "input": [
                ["role": "system", "content": request.system],
                ["role": "user", "content": request.user]
            ],
            "max_output_tokens": request.maxOutputTokens
        ]
        if request.reasoning != "none" {
            payload["reasoning"] = ["effort": request.reasoning]
        }

        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = request.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response: response, data: data, label: "OpenAI")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return extractOpenAIText(object ?? [:])
    }

    private func callAnthropic(_ request: LLMRequest) async throws -> String {
        let key = request.anthropicKey.trimmed
        guard !key.isEmpty else { throw RunnerError.missingAPIKey("Anthropic API Key fehlt.") }

        let payload: [String: Any] = [
            "model": request.model,
            "max_tokens": request.maxOutputTokens,
            "system": request.system,
            "stream": true,
            "messages": [
                ["role": "user", "content": request.user]
            ]
        ]

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = request.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        try validate(response: response, data: Data(), label: "Anthropic")
        return try await extractAnthropicStream(bytes)
    }

    private func validate(response: URLResponse, data: Data, label: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RunnerError.apiError("\(label) API Fehler \(http.statusCode): \(body.limited(to: 1000))")
        }
    }

    private func extractOpenAIText(_ object: [String: Any]) -> String {
        if let outputText = object["output_text"] as? String {
            return outputText
        }
        let output = object["output"] as? [[String: Any]] ?? []
        var parts: [String] = []
        for item in output {
            let content = item["content"] as? [[String: Any]] ?? []
            for contentItem in content {
                if let text = contentItem["text"] as? String {
                    parts.append(text)
                } else if let text = contentItem["output_text"] as? String {
                    parts.append(text)
                }
            }
        }
        let joined = parts.joined(separator: "\n\n")
        if !joined.trimmed.isEmpty { return joined }
        return (try? String(data: JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]), encoding: .utf8)) ?? ""
    }

    private func extractAnthropicStream(_ bytes: URLSession.AsyncBytes) async throws -> String {
        var parts: [String] = []

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst("data: ".count))
            if payload == "[DONE]" { continue }
            guard let data = payload.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["type"] as? String
            else { continue }

            if type == "content_block_delta",
               let delta = object["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                parts.append(text)
            } else if type == "error",
                      let error = object["error"] as? [String: Any],
                      let message = error["message"] as? String {
                throw RunnerError.apiError("Anthropic API Fehler: \(message)")
            }
        }

        return parts.joined()
    }

    private func networkMessage(for error: URLError, provider: AIProvider) -> String {
        if error.code == .timedOut {
            return "\(provider.label) API Timeout nach 180 Sekunden. Reduziere Ordnerkontext/Output oder starte erneut."
        }
        return "\(provider.label) Netzwerkfehler: \(error.localizedDescription)"
    }
}

enum RunnerError: LocalizedError {
    case missingAPIKey(String)
    case apiError(String)
    case missingSkill(String)
    case missingLibrary

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message), .apiError(let message), .missingSkill(let message):
            return message
        case .missingLibrary:
            return "AIConsultant-Bibliothek ist nicht geladen."
        }
    }

}
