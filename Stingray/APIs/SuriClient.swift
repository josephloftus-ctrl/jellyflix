//
//  SuriClient.swift
//  Stingray
//
//  REST client for the Suri media automation API.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.benlab.stingray", category: "suri")

// MARK: - Response Models

struct SuriRecommendation: Codable, Sendable, Identifiable {
    let id: String
    let itemId: String
    let itemType: String
    let score: Double
    let confidence: String
    let reason: String
    let action: String
    let status: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case itemType = "item_type"
        case score, confidence, reason, action, status
        case createdAt = "created_at"
    }
}

struct SuriRecommendationsResponse: Codable, Sendable {
    let recommendations: [SuriRecommendation]
}

struct SuriTorrent: Codable, Sendable, Identifiable {
    let hash: String
    let name: String
    let progress: Double
    let dlspeed: Int
    let upspeed: Int
    let size: Int64
    let eta: Int
    let state: String
    let category: String

    var id: String { hash }

    var isDownloading: Bool {
        state == "downloading" || state == "stalledDL" || state == "forcedDL" || state == "metaDL"
    }

    var isPaused: Bool {
        state == "pausedDL" || state == "pausedUP"
    }
}

struct SuriTransferInfo: Codable, Sendable {
    let dlSpeed: Int
    let upSpeed: Int
    let dlLimit: Int

    enum CodingKeys: String, CodingKey {
        case dlSpeed = "dl_speed"
        case upSpeed = "up_speed"
        case dlLimit = "dl_limit"
    }
}

struct SuriDownloadsResponse: Codable, Sendable {
    let torrents: [SuriTorrent]
    let transfer: SuriTransferInfo
}

struct SuriServiceHealth: Codable, Sendable {
    let status: String
    let code: Int?
    let error: String?
}

struct SuriServicesResponse: Codable, Sendable {
    let services: [String: SuriServiceHealth]
}

struct SuriDisk: Codable, Sendable, Identifiable {
    let path: String
    let total: Int64
    let used: Int64
    let free: Int64
    let percent: Double

    var id: String { path }
}

struct SuriDisksResponse: Codable, Sendable {
    let disks: [SuriDisk]
}

struct SuriFeedbackRequest: Codable, Sendable {
    let itemId: String
    let recommendationId: String?
    let action: String

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case recommendationId = "recommendation_id"
        case action
    }
}

// MARK: - Errors

enum SuriError: Error {
    case invalidURL
    case requestFailed(String)
    case decodeFailed(String)
}

// MARK: - Client

final class SuriClient: @unchecked Sendable {
    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    // MARK: Recommendations

    func getRecommendations() async throws -> [SuriRecommendation] {
        let data = try await get(path: "api/recommendations")
        let response = try decode(SuriRecommendationsResponse.self, from: data)
        return response.recommendations
    }

    func submitFeedback(itemId: String, recommendationId: String?, action: String) async throws {
        let body = SuriFeedbackRequest(itemId: itemId, recommendationId: recommendationId, action: action)
        try await post(path: "api/feedback", body: body)
    }

    func refreshRecommendations() async throws {
        try await post(path: "api/recommendations/refresh")
    }

    // MARK: Downloads

    func getDownloads() async throws -> SuriDownloadsResponse {
        let data = try await get(path: "api/dashboard/downloads")
        return try decode(SuriDownloadsResponse.self, from: data)
    }

    func pauseDownload(hash: String) async throws {
        try await post(path: "api/dashboard/downloads/\(hash)/pause")
    }

    func resumeDownload(hash: String) async throws {
        try await post(path: "api/dashboard/downloads/\(hash)/resume")
    }

    // MARK: Dashboard

    func getServiceHealth() async throws -> [String: SuriServiceHealth] {
        let data = try await get(path: "api/dashboard/services")
        let response = try decode(SuriServicesResponse.self, from: data)
        return response.services
    }

    func getDiskUsage() async throws -> [SuriDisk] {
        let data = try await get(path: "api/dashboard/disks")
        let response = try decode(SuriDisksResponse.self, from: data)
        return response.disks
    }

    // MARK: - Networking

    private func get(path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            logger.error("Suri GET \(path) failed: \(error.localizedDescription)")
            throw SuriError.requestFailed(error.localizedDescription)
        }
        return data
    }

    @discardableResult
    private func post(path: String, body: (any Encodable)? = nil) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("Suri POST \(path) failed: \(error.localizedDescription)")
            throw SuriError.requestFailed(error.localizedDescription)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Suri decode failed: \(error.localizedDescription)")
            throw SuriError.decodeFailed(error.localizedDescription)
        }
    }
}
