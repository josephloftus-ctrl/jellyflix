//
//  DesignSystem.swift
//  Stingray
//
//  Design tokens for consistent UI across the app.
//

import SwiftUI

// MARK: - Colors

enum StingrayColors {
    static let backgroundGradientTop = Color(red: 0, green: 0.145, blue: 0.223)
    static let backgroundGradientBottom = Color(red: 0, green: 0.063, blue: 0.153)
    static let accent = Color(red: 0, green: 0.729, blue: 1)
    static let accentDark = Color(red: 0, green: 0.09, blue: 0.945)
    static let focusGlow = Color(red: 0.3, green: 0.6, blue: 1)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let errorTint = Color.red.opacity(0.3)
}

// MARK: - Spacing

enum StingraySpacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 16
    static let md: CGFloat = 24
    static let lg: CGFloat = 40
    static let xl: CGFloat = 64
}

// MARK: - Typography

enum StingrayFont {
    static let heroTitle: Font = .largeTitle.bold()
    static let sectionTitle: Font = .title2.bold()
    static let cardTitle: Font = .footnote.bold()
    static let metadata: Font = .caption2
}

// MARK: - Animation

enum StingrayAnimation {
    static let focusSpring: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    static let shelfReveal: Animation = .spring(.smooth)
    static let fadeIn: Animation = .easeOut(duration: 0.4)
    static let backgroundBlur: Animation = .smooth(duration: 0.5)
    static let staggerDelay: Double = 0.05
}

// MARK: - Card Dimensions

enum StingrayCard {
    struct Dimensions {
        let width: CGFloat
        let height: CGFloat
        let imageHeight: CGFloat
    }

    static let standard = Dimensions(width: 240, height: 420, imageHeight: 340)
    static let hero = Dimensions(width: 400, height: 560, imageHeight: 480)
    static let episode = Dimensions(width: 400, height: 325, imageHeight: 225)
}
