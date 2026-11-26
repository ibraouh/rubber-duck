import Foundation

/// Talks to the Claude Messages API over HTTPS. Swift has no official Anthropic SDK,
/// so this builds the requests by hand.
final class ClaudeCoach: IdeaCoach {
    static let model = "claude-opus-5-5"

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2026-10-21"
    /// Server-side refusal fallbacks, and dropping (instead of rejecting) any replayed
    /// thinking block whose conversation no longer matches.
    private static let betas = "server-side-fallback-2026-07-01,thinking-binding-controls-2026-08-01"

    private let apiKey: String
    private let urlSession: URLSession

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 600
        urlSession = URLSession(configuration: configuration)
    }

    func reply(to history: [TranscriptMessage], buildingIdeas: Bool) async throws -> CoachReply {
        // Ideas get more thinking than questions. Effort sits outside the replayed
        // history, so changing it doesn't invalidate earlier reasoning.
        let response = try await send(
            system: Prompts.coachSystem,
            messages: history.map(Self.apiMessage),
            schema: Schemas.turn,
            effort: buildingIdeas ? "high" : "medium"
        )
        let turn = try Self.decode(CoachTurn.self, from: response.text)
        return CoachReply(turn: turn, rawContent: response.rawContent)
    }

    func card(for transcript: String) async throws -> IdeaCard {
        let response = try await send(
            system: Prompts.cardSystem,
            messages: [["role": "user", "content": transcript]],
            schema: Schemas.card,
            effort: "medium"
        )
        return try Self.decode(IdeaCard.self, from: response.text)
    }

    func look(for request: String) async throws -> IdeaLook {
        let response = try await send(
            system: Prompts.lookSystem,
            messages: [["role": "user", "content": request]],
            schema: Schemas.look,
            effort: "low"
        )
        return try Self.decode(IdeaLook.self, from: response.text)
    }

    // MARK: - Request

    private struct APIResponse {
        var text: String
        var rawContent: Data?
    }

    private func send(system: String, messages: [[String: Any]], schema: [String: Any], effort: String) async throws -> APIResponse {
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "system": system,
            "messages": messages,
            "thinking": [
                "type": "adaptive",
                "block_binding": ["prefix_mismatch_behavior": "drop_block"],
            ],
            "output_config": [
                "effort": effort,
                "format": ["type": "json_schema", "schema": schema],
            ],
            "fallbacks": "default",
            "cache_control": ["type": "ephemeral"],
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue(Self.betas, forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var attempt = 0
        while true {
            let (data, response) = try await urlSession.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200 {
                return try Self.parse(data)
            }
            let retryable = status == 408 || status == 409 || status == 429 || status >= 500
            if retryable, attempt < 2 {
                attempt += 1
                try await Task.sleep(for: .seconds(2 * attempt))
                continue
            }
            throw CoachError.http(status: status, message: Self.errorMessage(from: data))
        }
    }

    // MARK: - Response

    private static func parse(_ data: Data) throws -> APIResponse {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else {
            throw CoachError.badResponse("Claude sent back something unexpected.")
        }

        switch json["stop_reason"] as? String {
        case "refusal":
            let details = json["stop_details"] as? [String: Any]
            throw CoachError.refusal(details?["explanation"] as? String)
        case "max_tokens":
            throw CoachError.truncated
        default:
            break
        }

        let text = content
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        let raw = try? JSONSerialization.data(withJSONObject: replayable(content))
        return APIResponse(text: text, rawContent: raw)
    }

    /// After a refusal fallback, only text may be echoed from before the last
    /// `fallback` block; the block itself stays where it was.
    private static func replayable(_ content: [[String: Any]]) -> [[String: Any]] {
        guard let boundary = content.lastIndex(where: { $0["type"] as? String == "fallback" }) else {
            return content
        }
        return content.enumerated().compactMap { index, block in
            if index < boundary, block["type"] as? String != "text" { return nil }
            return block
        }
    }

    private static func apiMessage(_ message: TranscriptMessage) -> [String: Any] {
        switch message.role {
        case .user:
            return ["role": "user", "content": message.text]
        case .assistant:
            if let raw = message.rawContent,
               let blocks = try? JSONSerialization.jsonObject(with: raw) as? [[String: Any]] {
                return ["role": "assistant", "content": blocks]
            }
            return ["role": "assistant", "content": [["type": "text", "text": message.text]]]
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: Data(text.utf8))
        } catch {
            throw CoachError.badResponse("Couldn't read Claude's reply. Try again.")
        }
    }

    private static func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
