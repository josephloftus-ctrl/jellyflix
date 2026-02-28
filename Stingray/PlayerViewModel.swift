//
//  PlayerViewModel.swift
//  Stingray
//
//  Created by Ben Roberts on 12/4/25.
//

import AVKit
import os
import SwiftUI

private let logger = Logger(subsystem: "com.benlab.stingray", category: "playerVM")

@MainActor
@Observable
final class PlayerViewModel: Hashable {
    /// Player with formatted URL already set
    public var player: AVPlayer?
    /// Media that contains the source to play
    public var media: any MediaProtocol
    /// Media source in play
    public var mediaSourceID: String {
        didSet {
            switch self.media.mediaType {
            case .unknown:
                break
            case .movies(let mediaSources):
                self.mediaSource = mediaSources.first { $0.id == self.mediaSourceID } ?? self.mediaSource
                return
            case .tv(let seasons):
                guard let seasons = seasons else { return }
                for season in seasons {
                    for episode in season.episodes {
                        if let mediaSource = episode.mediaSources.first, mediaSource.id == self.mediaSourceID {
                            self.mediaSource = mediaSource
                            return
                        }
                    }
                }
            }
        }
    }
    /// Quickly get the media source from the media source ID
    public private(set) var mediaSource: any MediaSourceProtocol
    
    /// Time to start the player at
    public var startTime: CMTime
    /// Current player progress (exposed for observation)
    public var playerProgress: PlayerProtocol?
    /// Whether we're attempting a reconnect
    public var isRetrying: Bool = false

    /// Number of automatic retries attempted
    @ObservationIgnored private var retryCount = 0
    /// Max auto-retries before surfacing error
    @ObservationIgnored private let maxRetries = 1
    /// KVO observer for player item status
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    
    /// Server to stream from
    @ObservationIgnored public let streamingService: any StreamingServiceProtocol
    /// Seasons of a TV show if available (may be a movie)
    @ObservationIgnored public let seasons: [(any TVSeasonProtocol)]?
    /// Store and restore the current navigation path
    @ObservationIgnored public var navigationPath: NavigationPath?
    
    // Hashable Conformance
    static func == (lhs: PlayerViewModel, rhs: PlayerViewModel) -> Bool {
        lhs.mediaSourceID == rhs.mediaSourceID &&
        lhs.startTime == rhs.startTime
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(media.id)
        hasher.combine(startTime.seconds)
    }
    
    /// Normal init for setting up a player
    public init(
        media: any MediaProtocol,
        mediaSource: any MediaSourceProtocol,
        startTime: CMTime?,
        streamingService: StreamingServiceProtocol,
        seasons: [any TVSeasonProtocol]?
    ) {
        self.player = nil
        self.startTime = startTime ?? .zero
        self.streamingService = streamingService
        self.seasons = seasons
        self.playerProgress = nil
        self.mediaSourceID = mediaSource.id
        self.mediaSource = mediaSource
        self.media = media
        
        var subtitleID: String?
        var bitrate: Bitrate = .full
        
        if let defaultUser = UserModel.shared.getDefaultUser() {
            // Setup subtitles
            if defaultUser.usesSubtitles {
                subtitleID = self.mediaSource.subtitleStreams.first {
                    $0.isDefault
                }?.id ?? self.mediaSource.subtitleStreams.first?.id
            }
            // Setup bitrate
            if let bitrateBits = defaultUser.bitrate {
                bitrate = .limited(bitrateBits)
            }
        }
        
        self.savePlaybackDate()
        self.newPlayer(
            startTime: self.startTime,
            videoID: self.mediaSource.videoStreams.first { $0.isDefault }?.id ?? (self.mediaSource.videoStreams.first?.id ?? "0"),
            audioID: self.mediaSource.audioStreams.first { $0.isDefault }?.id ?? (self.mediaSource.audioStreams.first?.id ?? "1"),
            subtitleID: subtitleID,
            bitrate: bitrate
        )
        
    }
    
    /// Creates a new player based on current state
    /// - Parameters:
    ///   - startTime: Where the video should start from
    ///   - videoID: Video stream identifier. Nil = existing video ID
    ///   - audioID: Audio stream identifier. Nil = existing audio ID
    ///   - subtitleID: Subtitle stream identifier (empty for no subtitles). Nil = existing subtitle ID
    ///   - bitrate: The video's bitrate in bits per second
    public func newPlayer(
        startTime: CMTime,
        videoID: String? = nil,
        audioID: String? = nil,
        subtitleID: String? = nil,
        bitrate: Bitrate? = nil
    ) {
        self.stopPlayer()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
        
        var title = ""
        var subtitle = ""
        
        switch self.media.mediaType {
        case .tv(let seasons):
            if let seasons = seasons { // TV Shows
                for season in seasons {
                    if let episode = (season.episodes.first { $0.mediaSources.first?.id == self.mediaSource.id }) {
                        subtitle = "\(season.title), Episode \(episode.episodeNumber)"
                        break
                    }
                }
                let allEpisodes = seasons.flatMap(\.episodes)
                let currentEpisode = allEpisodes.first { $0.mediaSources.first?.id == self.mediaSource.id }
                title = currentEpisode?.title ?? ""
            }
            else { title = self.mediaSource.name }
        case .movies(let sources):
            title = self.media.title
            if sources.count > 1 { subtitle = self.mediaSource.name }
        default: title = self.media.title
        }
        
        guard let player = streamingService.playbackStart(
            mediaSource: self.mediaSource,
            videoID: videoID ?? self.playerProgress?.videoID ?? "0",
            audioID: audioID ?? self.playerProgress?.audioID ?? "1",
            subtitleID: subtitleID ?? self.playerProgress?.subtitleID, // nil is no subtitles
            bitrate: bitrate ?? self.playerProgress?.bitrate ?? .full,
            title: title,
            subtitle: subtitle
        )
        else { return }
        
        // Buffer and bitrate configuration
        if let playerItem = player.currentItem {
            playerItem.preferredForwardBufferDuration = 30
            if case .limited(let bps) = bitrate ?? self.playerProgress?.bitrate ?? .full {
                playerItem.preferredPeakBitRate = Double(bps)
            }
        }

        self.player = player
        self.playerProgress = streamingService.playerProgress // Sync to view model
        self.player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self.player?.play()

        // Observe player item status for error recovery
        self.statusObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let errorDesc = item.error?.localizedDescription ?? "unknown"
            logger.error("AVPlayerItem failed: \(errorDesc)")
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.retryCount < self.maxRetries {
                    self.retryCount += 1
                    logger.info("Auto-retrying playback (attempt \(self.retryCount))")
                    self.isRetrying = true
                    let currentTime = self.player?.currentTime() ?? startTime
                    self.newPlayer(
                        startTime: currentTime,
                        videoID: self.playerProgress?.videoID,
                        audioID: self.playerProgress?.audioID,
                        subtitleID: self.playerProgress?.subtitleID,
                        bitrate: self.playerProgress?.bitrate
                    )
                    try? await Task.sleep(for: .seconds(1))
                    self.isRetrying = false
                } else {
                    logger.error("Max retries reached, playback failed")
                }
            }
        }
        
        // Update user settings
        guard var currentUser = UserModel.shared.getDefaultUser() else { return }
        currentUser.usesSubtitles = self.playerProgress?.subtitleID != nil
        switch bitrate {
        case .full, .none:
            currentUser.bitrate = nil
        case .limited(let newBitrate):
            currentUser.bitrate = newBitrate
        }
        UserModel.shared.updateUser(currentUser)
    }
    
    /// Creates a new player based on current state and new episode
    /// - Parameter episode: Episode to transition into
    public func newPlayer(episode: any TVEpisodeProtocol) {
        guard let oldVideoStream = mediaSource.videoStreams.first(where: { self.playerProgress?.videoID == $0.id }),
              let newVideoStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldVideoStream, streamType: .video),
              let oldAudioStream = mediaSource.audioStreams.first(where: { self.playerProgress?.audioID == $0.id }),
              let newAudioStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldAudioStream, streamType: .audio)
        else { return }
        var newSubtitleStream: (any MediaStreamProtocol)?
        if let oldSubtitleStream = mediaSource.subtitleStreams.first(where: { self.playerProgress?.subtitleID == $0.id }) {
            newSubtitleStream = episode.mediaSources.first?.getSimilarStream(baseStream: oldSubtitleStream, streamType: .subtitle)
        }
        self.newPlayer(startTime: .zero, videoID: newVideoStream.id, audioID: newAudioStream.id, subtitleID: newSubtitleStream?.id)
    }
    
    func stopPlayer() {
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
        self.playerProgress = nil
        streamingService.playbackEnd()
    }
    
    func savePlaybackDate() {
        switch self.media.mediaType {
        case .tv(let seasons):
            if var seasons = seasons {
                for seasonIndex in seasons.indices {
                    for episodeIndex in seasons[seasonIndex].episodes.indices {
                        let episode = seasons[seasonIndex].episodes[episodeIndex]
                        if (episode.mediaSources.contains { $0.id == self.mediaSource.id }) {
                            seasons[seasonIndex].episodes[episodeIndex].lastPlayed = Date.now
                            if self.mediaSource.startPoint >= self.mediaSource.duration * 0.9 ||
                                self.mediaSource.startPoint < self.mediaSource.duration * 0.1 {
                                self.mediaSource.startPoint = 0
                            }
                            
                            logger.debug("Start: \(self.mediaSource.startPoint), 10%: \(self.mediaSource.duration * 0.1), 90%: \(self.mediaSource.duration * 0.9)")
                        }
                    }
                }
            }
        default: break
        }
    }
    
    deinit {
        player?.pause()
        streamingService.playbackEnd()
    }
}
