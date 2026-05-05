//
//  AIProxyService.swift
//  MigraineIQ
//
//  Single entry point for all AI calls. Routes to the Cloudflare Worker
//  proxy with shared-secret + per-install rate-limit auth.
//
//  Headers sent on every call:
//    X-App-Secret: <APP_PROXY_SECRET from Info.plist>
//    X-Install-Id: <UUID from InstallIdentity>
//
//  In Phase 2 this gets wrapped by an AIInsightsRepository implementing the
//  AIInsightsRepositoryProtocol from Domain/Repositories/.
//

import Foundation

actor AIProxyService {
    enum AIProxyError: Error, LocalizedError {
        case missingConfig
        case authFailed
        case rateLimited(retryAfter: Int)
        case serverError(Int)
        case decodingFailed(Error)
        case streamFailed

        var errorDescription: String? {
            switch self {
            case .missingConfig: return "Proxy URL or secret missing from Info.plist."
            case .authFailed: return "Authentication failed."
            case .rateLimited(let s): return "Rate limited. Try again in \(s) seconds."
            case .serverError(let code): return "Proxy returned HTTP \(code)."
            case .decodingFailed(let e): return "Failed to decode response: \(e.localizedDescription)"
            case .streamFailed: return "AI stream failed."
            }
        }
    }

    private let baseURL: URL
    private let secret: String
    private let session: URLSession
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(session: URLSession = .shared) throws {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "APP_PROXY_URL") as? String,
              let url = URL(string: urlString),
              let secret = Bundle.main.object(forInfoDictionaryKey: "APP_PROXY_SECRET") as? String,
              !secret.isEmpty else {
            throw AIProxyError.missingConfig
        }
        self.baseURL = url
        self.secret = secret
        self.session = session
    }

    // MARK: - Endpoint methods -------------------------------------------

    func recomputeTriggers(events: [HeadacheEventDTO],
                           context: HealthContextDTO) async throws -> [TriggerInsightDTO] {
        struct Body: Encodable { let events: [HeadacheEventDTO]; let context: HealthContextDTO }
        struct Response: Decodable { let insights: [TriggerInsightDTO] }
        let resp: Response = try await post(path: "v1/triggers", body: Body(events: events, context: context))
        return resp.insights
    }

    func predictNext24h(_ context: PredictionContextDTO) async throws -> PredictiveAlertDTO {
        try await post(path: "v1/predict", body: context)
    }

    /// Streaming chat. Yields response tokens as they arrive.
    func askCoach(question: String,
                  context: CoachContextDTO,
                  history: [CoachMessageDTO] = []) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    struct Body: Encodable {
                        let question: String
                        let context: CoachContextDTO
                        let conversationHistory: [CoachMessageDTO]
                    }
                    let req = try makeRequest(
                        path: "v1/coach",
                        body: Body(question: question, context: context, conversationHistory: history)
                    )

                    let (bytes, response) = try await session.bytes(for: req)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish(throwing: AIProxyError.streamFailed)
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        if let data = payload.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                           let token = chunk.choices.first?.delta.content {
                            continuation.yield(token)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Plumbing ---------------------------------------------------

    private func post<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        let req = try makeRequest(path: path, body: body)
        let (data, response) = try await session.data(for: req)
        try check(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AIProxyError.decodingFailed(error)
        }
    }

    private func makeRequest<Body: Encodable>(path: String, body: Body) throws -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(secret, forHTTPHeaderField: "X-App-Secret")
        req.setValue(InstallIdentity.current, forHTTPHeaderField: "X-Install-Id")
        req.timeoutInterval = 30
        req.httpBody = try encoder.encode(body)
        return req
    }

    private func check(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIProxyError.serverError(0)
        }
        switch http.statusCode {
        case 200: return
        case 401: throw AIProxyError.authFailed
        case 429:
            let retry = (try? JSONDecoder().decode(RateLimitBody.self, from: data))?.retryAfter ?? 60
            throw AIProxyError.rateLimited(retryAfter: retry)
        default:
            throw AIProxyError.serverError(http.statusCode)
        }
    }
}

// MARK: - Stream payloads -----------------------------------------------

private struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}

private struct RateLimitBody: Decodable { let retryAfter: Int }
