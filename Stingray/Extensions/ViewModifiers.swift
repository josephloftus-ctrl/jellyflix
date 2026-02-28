//
//  ViewModifiers.swift
//  Stingray
//
//  Reusable view modifiers for glass effects, focus animations, and transitions.
//

import SwiftUI

// MARK: - Glass Background

struct GlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .padding(-padding)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = 24, padding: CGFloat = 20) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Entrance Animation

struct EntranceAnimationModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
            .animation(
                StingrayAnimation.fadeIn.delay(Double(index) * StingrayAnimation.staggerDelay),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

extension View {
    func entranceAnimation(index: Int) -> some View {
        modifier(EntranceAnimationModifier(index: index))
    }
}

// MARK: - Progress Overlay

struct ProgressOverlayModifier: ViewModifier {
    let progress: Double
    var height: CGFloat = 4
    var color: Color = StingrayColors.accent

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if progress > 0 && progress < 1 {
                GeometryReader { geo in
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
        }
    }
}

extension View {
    func progressOverlay(_ progress: Double) -> some View {
        modifier(ProgressOverlayModifier(progress: progress))
    }
}
