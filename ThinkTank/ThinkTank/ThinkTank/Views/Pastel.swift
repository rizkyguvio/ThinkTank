import SwiftUI

/// Elegant, intelligent color system for ThinkTank.
/// Now acts as a dynamic proxy for the ThemeManager's selected theme.
enum Pastel {

    static var current: AppTheme {
        ThemeManager.shared.currentTheme
    }

    // MARK: - Core Palette

    static var background: Color { current.background }
    static var radialCenter: Color { current.radialCenter }
    static var radialEdge: Color { current.radialEdge }
    static var accent: Color { current.accent }
    static var paper: Color { current.paper }
    static var header: Color { current.header }
    static var primaryText: Color { current.primaryText }
    static var secondaryText: Color { current.secondaryText }

    // MARK: - Status Colors

    static var sky: Color { current.sky }
    static var mint: Color { current.mint }
    static var peach: Color { current.peach }
    static var rose: Color { current.rose }
    static var lavender: Color { accent }

    // MARK: - Gradients

    static var radialBackground: some View {
        ThemeBackgroundView()
            .ignoresSafeArea()
    }

    // MARK: - Dynamic helpers

    static func forHash(_ value: Int) -> Color {
        let palette: [Color] = [accent, sky, mint, peach, rose]
        let index = abs(value) % palette.count
        return palette[index]
    }

    static func color(for status: IdeaStatus) -> Color {
        switch status {
        case .active:   return sky
        case .resolved: return mint
        case .archived: return peach
        }
    }
}

/// Helper view to react to theme changes specifically for backgrounds
struct ThemeBackgroundView: View {
    // This empty state observer triggers a redraw when ThemeManager (an @Observable) changes
    @State private var manager = ThemeManager.shared
    
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [manager.currentTheme.radialCenter, manager.currentTheme.radialEdge]),
            center: .top,
            startRadius: 0,
            endRadius: 800
        )
    }
}
