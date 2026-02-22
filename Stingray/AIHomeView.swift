//
//  AIHomeView.swift
//  Stingray
//
//  Created by Joseph Loftus on 2/22/26.
//

import SwiftUI

/// AI-powered home screen that displays Conduit recommendation rows
struct AIHomeView: View {
    let conduitClient: ConduitClient
    let streamingService: StreamingServiceProtocol
    @Binding var navigation: NavigationPath

    @State private var rows: [LoadedRow] = []
    @State private var heroMedia: SlimMedia?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero banner
                if let hero = heroMedia {
                    HeroView(media: hero, streamingService: streamingService) {
                        navigation.append(hero)
                    }
                    .focusSection()
                }

                // Error banner
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                // Loading indicator
                if isLoading && rows.isEmpty {
                    ProgressView("Loading recommendations...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                }

                // Recommendation rows
                ForEach(rows) { row in
                    RecommendationRowView(
                        row: row,
                        streamingService: streamingService,
                        navigation: $navigation
                    )
                    .padding(.horizontal, 48)
                }
                .scrollClipDisabled()

                SystemInfoView(streamingService: streamingService)
                    .padding(.top, 32)
            }
        }
        .task {
            await loadRecommendations()
        }
    }

    private func loadRecommendations() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await conduitClient.getRecommendations(userId: streamingService.userID)

            // Cache the response
            cacheRecommendations(response)

            await resolveRows(from: response)
        } catch {
            // Try loading from cache
            if let cached = loadCachedRecommendations() {
                errorMessage = "Showing cached recommendations"
                await resolveRows(from: cached)
            } else {
                errorMessage = "Could not load recommendations"
            }
        }

        isLoading = false
    }

    private func resolveRows(from response: RecommendationsResponse) async {
        guard let networkAPI = (streamingService as? JellyfinModel)?.networkAPI else { return }
        let accessToken = (streamingService as? JellyfinModel)?.accessToken ?? ""

        for row in response.rows {
            guard !row.itemIds.isEmpty else { continue }

            do {
                let media = try await networkAPI.getItemsByIds(accessToken: accessToken, ids: row.itemIds)

                let loadedRow = LoadedRow(
                    title: row.title,
                    reason: row.reason,
                    media: media,
                    type: row.type
                )

                rows.append(loadedRow)

                // Set hero from first "recommended" row
                if heroMedia == nil && row.type == "recommended" {
                    heroMedia = media.first
                }
            } catch {
                print("Failed to resolve row '\(row.title)': \(error)")
            }
        }

        // Fallback hero from first row if no "recommended" type found
        if heroMedia == nil, let firstMedia = rows.first?.media.first {
            heroMedia = firstMedia
        }
    }

    // MARK: - Caching

    private static let cacheKey = "cached_recommendations"

    private func cacheRecommendations(_ response: RecommendationsResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        UserDefaults(suiteName: "group.com.benlab.stingray")?.set(data, forKey: Self.cacheKey)
    }

    private func loadCachedRecommendations() -> RecommendationsResponse? {
        guard let data = UserDefaults(suiteName: "group.com.benlab.stingray")?.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(RecommendationsResponse.self, from: data)
    }
}
