//
//  AIHomeView.swift
//  Stingray
//
//  Created by Joseph Loftus on 2/22/26.
//

import os
import SwiftUI

private let logger = Logger(subsystem: "com.benlab.stingray", category: "aiHome")

/// AI-powered home screen that displays Conduit recommendation rows
struct AIHomeView: View {
    let conduitClient: ConduitClient
    var suriClient: SuriClient?
    let streamingService: StreamingServiceProtocol
    @Binding var navigation: NavigationPath

    @State private var rows: [LoadedRow] = []
    @State private var heroMedia: SlimMedia?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var sieveRecs: [SuriRecommendation] = []
    @State private var sieveError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero banner
                if let hero = heroMedia {
                    HeroView(media: hero, streamingService: streamingService) {
                        navigation.append(hero)
                    }
                    .focusSection()
                    .entranceAnimation(index: 0)
                }

                // Error banner
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(StingrayColors.textSecondary)
                        .padding()
                }

                // Loading indicator
                if isLoading && rows.isEmpty {
                    VStack(spacing: StingraySpacing.sm) {
                        ProgressView()
                        Text("Loading recommendations...")
                            .foregroundStyle(StingrayColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                }

                // Recommendation rows
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    RecommendationRowView(
                        row: row,
                        rowIndex: index,
                        streamingService: streamingService,
                        navigation: $navigation
                    )
                    .padding(.horizontal, 48)
                }
                .scrollClipDisabled()

                // Sieve Picks
                if !sieveRecs.isEmpty {
                    SievePicksSection(recommendations: $sieveRecs, suriClient: suriClient)
                        .padding(.horizontal, 48)
                        .padding(.vertical)
                        .entranceAnimation(index: rows.count + 2)
                }

                if let sieveError {
                    Text(sieveError)
                        .font(.caption)
                        .foregroundStyle(StingrayColors.textSecondary)
                        .padding(.horizontal, 48)
                }

                SystemInfoView(streamingService: streamingService)
                    .padding(.top, StingraySpacing.lg)
            }
        }
        .task {
            await loadRecommendations()
            await loadSieveRecommendations()
        }
    }

    private func loadRecommendations() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await conduitClient.getRecommendations(userId: streamingService.userID)
            cacheRecommendations(response)
            await resolveRows(from: response)
        } catch {
            logger.warning("Conduit fetch failed, trying cache: \(error.localizedDescription)")
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
                logger.warning("Failed to resolve row '\(row.title)': \(error)")
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

    // MARK: - Sieve

    private func loadSieveRecommendations() async {
        guard let suriClient else { return }
        do {
            sieveRecs = try await suriClient.getRecommendations()
            sieveError = nil
        } catch {
            logger.warning("Sieve fetch failed: \(error.localizedDescription)")
            sieveError = "Could not load Sieve recommendations"
        }
    }
}

// MARK: - Sieve Picks Section

struct SievePicksSection: View {
    @Binding var recommendations: [SuriRecommendation]
    var suriClient: SuriClient?

    var body: some View {
        VStack(alignment: .leading, spacing: StingraySpacing.xs) {
            Text("Sieve Picks")
                .font(StingrayFont.sectionTitle)
                .padding(.horizontal, StingraySpacing.xs)
                .padding(.vertical, 6)
                .glassBackground(cornerRadius: 12, padding: 8)

            Text("AI-curated recommendations from your media stack")
                .font(.subheadline)
                .foregroundStyle(StingrayColors.textSecondary)

            ScrollView(.horizontal) {
                LazyHStack(spacing: StingraySpacing.md) {
                    ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, rec in
                        SieveCard(recommendation: rec, suriClient: suriClient) { action in
                            withAnimation {
                                recommendations.removeAll { $0.id == rec.id }
                            }
                        }
                        .entranceAnimation(index: index)
                    }
                }
            }
        }
        .focusSection()
    }
}

// MARK: - Sieve Card

private struct SieveCard: View {
    let recommendation: SuriRecommendation
    var suriClient: SuriClient?
    var onAction: (String) -> Void

    @State private var isFocused = false
    @State private var isActing = false

    var body: some View {
        Button {
            approve()
        } label: {
            VStack(alignment: .leading, spacing: StingraySpacing.xs) {
                HStack {
                    Text(recommendation.itemType.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(StingrayColors.accent.opacity(0.2), in: Capsule())
                        .foregroundStyle(StingrayColors.accent)

                    if recommendation.action == "auto_acquire" {
                        Text("Auto")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2), in: Capsule())
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Text("\(Int(recommendation.score * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(scoreColor)
                }

                Text(recommendation.itemId)
                    .font(StingrayFont.cardTitle)
                    .lineLimit(2)

                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(StingrayColors.textSecondary)
                    .lineLimit(3)

                Spacer()

                HStack(spacing: StingraySpacing.sm) {
                    Button {
                        approve()
                    } label: {
                        Label("Approve", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green.opacity(0.8))
                    .disabled(isActing)

                    Button {
                        reject()
                    } label: {
                        Label("Reject", systemImage: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red.opacity(0.8))
                    .disabled(isActing)
                }
            }
            .padding(StingraySpacing.sm)
            .frame(width: 280, height: 220)
            .glassBackground(cornerRadius: 20, padding: StingraySpacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var scoreColor: Color {
        if recommendation.score >= 0.85 { return .green }
        if recommendation.score >= 0.7 { return .yellow }
        return StingrayColors.textSecondary
    }

    private func approve() {
        guard !isActing else { return }
        isActing = true
        Task {
            try? await suriClient?.submitFeedback(
                itemId: recommendation.itemId,
                recommendationId: recommendation.id,
                action: "approved"
            )
            onAction("approved")
        }
    }

    private func reject() {
        guard !isActing else { return }
        isActing = true
        Task {
            try? await suriClient?.submitFeedback(
                itemId: recommendation.itemId,
                recommendationId: recommendation.id,
                action: "rejected"
            )
            onAction("rejected")
        }
    }
}
