//
//  LiveView.swift
//  Stingray
//

import SwiftUI

struct LiveView: View {
    var body: some View {
        VStack(spacing: StingraySpacing.md) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [StingrayColors.accent, StingrayColors.accentDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("Live TV")
                .font(StingrayFont.heroTitle)
            Text("Coming Soon")
                .font(StingrayFont.sectionTitle)
                .foregroundStyle(StingrayColors.textSecondary)
            Text("Live channels, free IPTV, and your personal media organized into stations.")
                .font(.body)
                .foregroundStyle(StingrayColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
