//
//  DownloadsView.swift
//  Stingray
//
//  Active qBittorrent downloads from Suri.
//

import SwiftUI

struct DownloadsView: View {
    let suriClient: SuriClient

    @State private var torrents: [SuriTorrent] = []
    @State private var transfer: SuriTransferInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StingraySpacing.sm) {
                // Header
                HStack {
                    Text("Downloads")
                        .font(StingrayFont.heroTitle)
                    Spacer()
                    if let transfer {
                        HStack(spacing: StingraySpacing.sm) {
                            Label(formatSpeed(transfer.dlSpeed), systemImage: "arrow.down.circle.fill")
                            Label(formatSpeed(transfer.upSpeed), systemImage: "arrow.up.circle.fill")
                        }
                        .font(.callout)
                        .foregroundStyle(StingrayColors.textSecondary)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.top, StingraySpacing.lg)

                if isLoading && torrents.isEmpty {
                    VStack(spacing: StingraySpacing.sm) {
                        ProgressView()
                        Text("Loading downloads...")
                            .foregroundStyle(StingrayColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(StingrayColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if torrents.isEmpty {
                    VStack(spacing: StingraySpacing.sm) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(StingrayColors.accent)
                        Text("No active downloads")
                            .foregroundStyle(StingrayColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(torrents) { torrent in
                        TorrentRow(torrent: torrent, suriClient: suriClient)
                            .padding(.horizontal, 48)
                    }
                }
            }
        }
        .onAppear { startRefreshing() }
        .onDisappear { refreshTask?.cancel() }
    }

    private func startRefreshing() {
        refreshTask = Task {
            while !Task.isCancelled {
                await loadDownloads()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func loadDownloads() async {
        do {
            let response = try await suriClient.getDownloads()
            torrents = response.torrents
            transfer = response.transfer
            errorMessage = nil
        } catch {
            if torrents.isEmpty {
                errorMessage = "Could not load downloads"
            }
        }
        isLoading = false
    }

    private func formatSpeed(_ bytesPerSec: Int) -> String {
        if bytesPerSec < 1024 { return "\(bytesPerSec) B/s" }
        let kb = Double(bytesPerSec) / 1024
        if kb < 1024 { return String(format: "%.0f KB/s", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB/s", mb)
    }
}

// MARK: - Torrent Row

private struct TorrentRow: View {
    let torrent: SuriTorrent
    let suriClient: SuriClient

    @State private var isToggling = false

    var body: some View {
        Button {
            togglePauseResume()
        } label: {
            VStack(alignment: .leading, spacing: StingraySpacing.xs) {
                HStack {
                    Text(torrent.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    statusBadge
                }

                ProgressView(value: torrent.progress)
                    .tint(torrent.isPaused ? StingrayColors.textSecondary : StingrayColors.accent)

                HStack {
                    Text("\(Int(torrent.progress * 100))%")
                    Text("·")
                    Text(formatSize(torrent.size))
                    Spacer()
                    if torrent.isDownloading {
                        Label(formatSpeed(torrent.dlspeed), systemImage: "arrow.down")
                        if torrent.eta > 0 {
                            Text("·")
                            Text(formatETA(torrent.eta))
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(StingrayColors.textSecondary)
            }
            .padding(StingraySpacing.sm)
            .glassBackground(cornerRadius: 16, padding: StingraySpacing.sm)
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            if torrent.isPaused { return ("Paused", .yellow) }
            if torrent.isDownloading { return ("Downloading", StingrayColors.accent) }
            if torrent.state == "uploading" || torrent.state == "stalledUP" { return ("Seeding", .green) }
            return (torrent.state.capitalized, StingrayColors.textSecondary)
        }()

        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }

    private func togglePauseResume() {
        isToggling = true
        Task {
            do {
                if torrent.isPaused {
                    try await suriClient.resumeDownload(hash: torrent.hash)
                } else {
                    try await suriClient.pauseDownload(hash: torrent.hash)
                }
            } catch {}
            isToggling = false
        }
    }

    private func formatSpeed(_ bytesPerSec: Int) -> String {
        if bytesPerSec < 1024 { return "\(bytesPerSec) B/s" }
        let kb = Double(bytesPerSec) / 1024
        if kb < 1024 { return String(format: "%.0f KB/s", kb) }
        let mb = kb / 1024
        return String(format: "%.1f MB/s", mb)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    private func formatETA(_ seconds: Int) -> String {
        if seconds <= 0 || seconds > 86400 * 7 { return "∞" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        let s = seconds % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
