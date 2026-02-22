//
//  ConduitClient.swift
//  Stingray
//
//  Created by Joseph Loftus on 2/22/26.
//

import Foundation

/// A single recommendation row from Conduit
struct RecommendationRow: Codable {
    let title: String
    let reason: String
    let itemIds: [String]
    let type: String

    enum CodingKeys: String, CodingKey {
        case title, reason, type
        case itemIds = "item_ids"
    }
}

/// Response from the Conduit recommendations endpoint
struct RecommendationsResponse: Codable {
    let rows: [RecommendationRow]
    let generatedAt: String?
    let stale: Bool?

    enum CodingKeys: String, CodingKey {
        case rows
        case generatedAt = "generated_at"
        case stale
    }
}

/// Errors from Conduit API calls
enum ConduitError: Error {
    case invalidURL
    case requestFailed(Error)
    case decodeFailed(Error)
}

/// Client for fetching AI recommendations from Conduit
final class ConduitClient {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Fetch recommendation rows from Conduit
    /// - Parameter userId: Jellyfin user ID
    /// - Returns: The recommendations response
    func getRecommendations(userId: String) async throws -> RecommendationsResponse {
        guard var components = URLComponents(url: baseURL.appendingPathComponent("/api/jellyfin-recs"), resolvingAgainstBaseURL: false) else {
            throw ConduitError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "userId", value: userId)]

        guard let url = components.url else {
            throw ConduitError.invalidURL
        }

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw ConduitError.requestFailed(error)
        }

        do {
            return try JSONDecoder().decode(RecommendationsResponse.self, from: data)
        } catch {
            throw ConduitError.decodeFailed(error)
        }
    }
}
