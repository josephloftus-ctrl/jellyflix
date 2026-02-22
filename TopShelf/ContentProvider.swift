//
//  ContentProvider.swift
//  TopShelf
//
//  Created by Ben Roberts on 12/11/25.
//

import TVServices

class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let streamingModel: StreamingServiceBasicProtocol
        do {
            streamingModel = try StreamingServiceBasicModel()
        } catch {
            print("TopShelf: Failed to initialize StreamingServiceBasicModel: \(error)")
            return nil
        }

        // Try AI recommendations from cache first
        if let aiSections = loadAIRecommendationSections(streamingModel: streamingModel), !aiSections.isEmpty {
            print("TopShelf: Returning \(aiSections.count) AI recommendation sections")
            return TVTopShelfSectionedContent(sections: aiSections)
        }

        // Fallback: fetch content from Jellyfin directly
        print("TopShelf: No cached AI recommendations, falling back to standard content")
        async let upNextMedia = streamingModel.retrieveUpNext()
        async let recentlyAddedMedia = streamingModel.retrieveRecentlyAdded(.all)

        let (upNext, recentlyAdded) = await (upNextMedia, recentlyAddedMedia)

        print("TopShelf: Retrieved \(upNext.count) up next items and \(recentlyAdded.count) recently added items")

        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

        if !upNext.isEmpty {
            let upNextItems = upNext.compactMap { media -> TVTopShelfSectionedItem? in
                createTopShelfItem(from: media, streamingModel: streamingModel, imageStyle: .landscape)
            }
            if !upNextItems.isEmpty {
                let upNextSection = TVTopShelfItemCollection(items: upNextItems)
                upNextSection.title = "Up Next"
                sections.append(upNextSection)
            }
        }

        if !recentlyAdded.isEmpty {
            let recentlyAddedItems = recentlyAdded.compactMap { media -> TVTopShelfSectionedItem? in
                createTopShelfItem(from: media, streamingModel: streamingModel, imageStyle: .poster)
            }
            if !recentlyAddedItems.isEmpty {
                let recentlyAddedSection = TVTopShelfItemCollection(items: recentlyAddedItems)
                recentlyAddedSection.title = "Recently Added"
                sections.append(recentlyAddedSection)
            }
        }

        guard !sections.isEmpty else {
            print("TopShelf: No sections to display")
            return nil
        }

        print("TopShelf: Returning \(sections.count) sections with content")
        return TVTopShelfSectionedContent(sections: sections)
    }

    // MARK: - AI Recommendations

    private func loadAIRecommendationSections(streamingModel: StreamingServiceBasicProtocol) -> [TVTopShelfItemCollection<TVTopShelfSectionedItem>]? {
        guard let data = UserDefaults(suiteName: "group.com.benlab.stingray")?.data(forKey: "cached_recommendations"),
              let response = try? JSONDecoder().decode(RecommendationsResponse.self, from: data) else {
            return nil
        }

        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

        for row in response.rows.prefix(3) {
            let items = row.itemIds.prefix(10).compactMap { itemId -> TVTopShelfSectionedItem? in
                let item = TVTopShelfSectionedItem(identifier: itemId)
                item.title = row.title

                // Use poster images for top shelf items
                if let imageURL = streamingModel.getImageURL(imageType: .primary, mediaID: itemId, width: 300) {
                    item.setImageURL(imageURL, for: .screenScale1x)
                }
                if let imageURL2x = streamingModel.getImageURL(imageType: .primary, mediaID: itemId, width: 600) {
                    item.setImageURL(imageURL2x, for: .screenScale2x)
                }
                item.imageShape = .poster

                if let displayURL = URL(string: "stingray://media?id=\(itemId)&parentID=None") {
                    item.displayAction = TVTopShelfAction(url: displayURL)
                }

                return item
            }

            if !items.isEmpty {
                let section = TVTopShelfItemCollection(items: items)
                section.title = row.title
                sections.append(section)
            }
        }

        return sections.isEmpty ? nil : sections
    }

    // MARK: - Standard Content

    private enum ImageStyle {
        case landscape
        case poster
    }

    private func createTopShelfItem(from media: SlimMedia, streamingModel: StreamingServiceBasicProtocol, imageStyle: ImageStyle) -> TVTopShelfSectionedItem? {
        let mediaID = media.id
        let item = TVTopShelfSectionedItem(identifier: mediaID)
        item.title = media.title

        switch imageStyle {
        case .landscape:
            item.imageShape = .hdtv
            if let imageURL = streamingModel.getImageURL(imageType: .backdrop, mediaID: mediaID, width: 800) {
                item.setImageURL(imageURL, for: .screenScale1x)
            }
            if let imageURL2x = streamingModel.getImageURL(imageType: .backdrop, mediaID: mediaID, width: 1600) {
                item.setImageURL(imageURL2x, for: .screenScale2x)
            }

        case .poster:
            item.imageShape = .poster
            if let imageURL = streamingModel.getImageURL(imageType: .primary, mediaID: mediaID, width: 300) {
                item.setImageURL(imageURL, for: .screenScale1x)
            }
            if let imageURL2x = streamingModel.getImageURL(imageType: .primary, mediaID: mediaID, width: 600) {
                item.setImageURL(imageURL2x, for: .screenScale2x)
            }
        }

        if let displayURL = URL(string: "stingray://media?id=\(mediaID)&parentID=\(media.parentID ?? "None")") {
            item.displayAction = TVTopShelfAction(url: displayURL)
        }

        return item
    }
}
