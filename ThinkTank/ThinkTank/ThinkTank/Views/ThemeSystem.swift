import SwiftUI
import WidgetKit

/// Defines the color requirements for any Think Tank theme.
protocol AppTheme {
    var id: String { get }
    var displayName: String { get }
    
    var background: Color { get }
    var radialCenter: Color { get }
    var radialEdge: Color { get }
    var accent: Color { get }
    var paper: Color { get }
    var header: Color { get }
    
    var primaryText: Color { get }
    var secondaryText: Color { get }
    
    var sky: Color { get }
    var mint: Color { get }
    var peach: Color { get }
    var rose: Color { get }
    
    var iconName: String? { get }
}

/// The original, elegant Think Tank identity.
struct ClassicPastelTheme: AppTheme {
    let id = "classic"
    let displayName = "Classic"
    
    let background = Color(red: 0.06, green: 0.09, blue: 0.16)
    let radialCenter = Color(red: 0.067, green: 0.11, blue: 0.20)
    let radialEdge = Color(red: 0.043, green: 0.075, blue: 0.145)
    let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    let paper = Color(red: 0.98, green: 0.97, blue: 0.95)
    let header = Color(red: 0.886, green: 0.91, blue: 0.941)
    
    let primaryText = Color.white
    let secondaryText = Color.white.opacity(0.6)
    
    let sky = Color(red: 0.40, green: 0.60, blue: 0.90)
    let mint = Color(red: 0.35, green: 0.75, blue: 0.65)
    let peach = Color(red: 0.90, green: 0.60, blue: 0.50)
    let rose = Color(red: 0.90, green: 0.45, blue: 0.55)
    
    let iconName: String? = nil // Default icon
}

/// A high-tech, bioluminescent dark mode.
struct MidnightTheme: AppTheme {
    let id = "midnight"
    let displayName = "Midnight"
    
    let background = Color(red: 0.01, green: 0.02, blue: 0.04)
    let radialCenter = Color(red: 0.02, green: 0.05, blue: 0.12)
    let radialEdge = Color(red: 0.0, green: 0.01, blue: 0.02)
    let accent = Color(red: 0.23, green: 0.51, blue: 0.96) // Cobalt
    let paper = Color(red: 0.94, green: 0.96, blue: 0.98)
    let header = Color(red: 0.7, green: 0.8, blue: 1.0)
    
    let primaryText = Color.white
    let secondaryText = Color.white.opacity(0.5)
    
    let sky = Color(red: 0.2, green: 0.6, blue: 1.0)
    let mint = Color(red: 0.0, green: 0.8, blue: 0.6)
    let peach = Color(red: 1.0, green: 0.5, blue: 0.3)
    let rose = Color(red: 1.0, green: 0.2, blue: 0.4)
    
    let iconName: String? = "AppIcon-Midnight"
}

/// A warm, tactile "Designer's Desk" feel.
struct StudioTheme: AppTheme {
    let id = "studio"
    let displayName = "Studio"
    
    let background = Color(red: 0.17, green: 0.15, blue: 0.13)
    let radialCenter = Color(red: 0.25, green: 0.22, blue: 0.18)
    let radialEdge = Color(red: 0.12, green: 0.10, blue: 0.08)
    let accent = Color(red: 0.85, green: 0.47, blue: 0.03) // Terracotta Gold
    let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
    let header = Color(red: 0.95, green: 0.90, blue: 0.85)
    
    let primaryText = Color.white
    let secondaryText = Color.white.opacity(0.5)
    
    let sky = Color(red: 0.9, green: 0.7, blue: 0.2)
    let mint = Color(red: 0.4, green: 0.6, blue: 0.1)
    let peach = Color(red: 0.8, green: 0.4, blue: 0.2)
    let rose = Color(red: 0.7, green: 0.2, blue: 0.1)
    
    let iconName: String? = "AppIcon-Studio"
}

/// A warm, premium light mode inspired by heavy-stock physical notebooks.
struct PaperTheme: AppTheme {
    let id = "paper_theme"
    let displayName = "Paper"
    
    let background = Color(red: 0.98, green: 0.976, blue: 0.965) // #FAF9F6
    let radialCenter = Color.white
    let radialEdge = Color(red: 0.94, green: 0.94, blue: 0.92)
    let accent = Color(red: 0.39, green: 0.40, blue: 0.95) // Original Indigo
    let paper = Color.white
    let header = Color(red: 0.2, green: 0.2, blue: 0.25)
    
    let primaryText = Color(red: 0.15, green: 0.15, blue: 0.18) // Deep Graphite
    let secondaryText = Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.6)
    
    let sky = Color(red: 0.0, green: 0.45, blue: 0.85)
    let mint = Color(red: 0.15, green: 0.65, blue: 0.5)
    let peach = Color(red: 0.85, green: 0.45, blue: 0.35)
    let rose = Color(red: 0.8, green: 0.2, blue: 0.3)
    
    let iconName: String? = "AppIcon-Paper"
}

@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    
    // Shared suite to sync with Widgets
    private let suiteName = "group.personal.ThinkTank.Gio"
    private let storageKey = "ThinkTank_SelectedTheme"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
    
    var currentTheme: AppTheme {
        didSet {
            sharedDefaults?.set(currentTheme.id, forKey: storageKey)
            updateAppIcon()
            HapticManager.shared.heavyImpact()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    let allThemes: [AppTheme] = [
        PaperTheme(),       // Light White
        MatchaTheme(),      // Light Green
        NordicTheme(),      // Cool Grey
        ClassicPastelTheme(),// Deep Blue
        MidnightTheme(),    // Deepest Black
        CyberpunkTheme(),   // Deep Void/Cyan
        SunsetTheme(),      // Deep Purple/Orange
        StudioTheme()       // Deep Brown/Gold
    ]
    
    private init() {
        let defaults = UserDefaults(suiteName: "group.personal.ThinkTank.Gio")
        let savedId = defaults?.string(forKey: "ThinkTank_SelectedTheme")
        
        switch savedId {
        case "midnight":    self.currentTheme = MidnightTheme()
        case "studio":      self.currentTheme = StudioTheme()
        case "paper_theme": self.currentTheme = PaperTheme()
        case "neon":        self.currentTheme = CyberpunkTheme()
        case "matcha":      self.currentTheme = MatchaTheme()
        case "sunset":      self.currentTheme = SunsetTheme()
        case "nordic":      self.currentTheme = NordicTheme()
        default:            self.currentTheme = ClassicPastelTheme()
        }
    }
    
    private func updateAppIcon() {
        let iconName = currentTheme.iconName
        
        DispatchQueue.main.async {
            guard UIApplication.shared.supportsAlternateIcons else { return }
            
            // Refined implementation: Bypasses the intrusive system alert for a more premium experience.
            if UIApplication.shared.alternateIconName != iconName {
                UIApplication.shared.setAlternateIconName(iconName) { error in
                    if let error = error {
                        print("Icon update failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

/// A futuristic, high-contrast neon theme.
struct CyberpunkTheme: AppTheme {
    let id = "neon"
    let displayName = "Cyberpunk"
    
    let background = Color(red: 0.05, green: 0.05, blue: 0.08)
    let radialCenter = Color(red: 0.1, green: 0.05, blue: 0.15)
    let radialEdge = Color.black
    let accent = Color(red: 0.0, green: 1.0, blue: 0.8) // Cyan
    // User Request: Keep paper color default (Classic)
    let paper = Color(red: 0.98, green: 0.97, blue: 0.95)
    let header = Color(red: 0.8, green: 0.2, blue: 1.0) // Bright Violet
    
    let primaryText = Color.white
    let secondaryText = Color(red: 0.0, green: 1.0, blue: 0.8).opacity(0.9)
    
    let sky = Color(red: 0.0, green: 0.8, blue: 1.0)
    let mint = Color(red: 0.0, green: 1.0, blue: 0.5)
    let peach = Color(red: 1.0, green: 0.0, blue: 0.8) // Magenta
    let rose = Color(red: 1.0, green: 0.2, blue: 0.4)
    
    let iconName: String? = "AppIcon-Neon"
}

/// A calm, nature-inspired palette.
struct MatchaTheme: AppTheme {
    let id = "matcha"
    let displayName = "Matcha"
    
    let background = Color(red: 0.94, green: 0.96, blue: 0.94) // Mint cream
    let radialCenter = Color(red: 0.9, green: 0.95, blue: 0.9)
    let radialEdge = Color(red: 0.88, green: 0.92, blue: 0.88)
    let accent = Color(red: 0.35, green: 0.5, blue: 0.25) // Darker Olive for contrast
    // User Request: Keep paper color default
    let paper = Color(red: 0.98, green: 0.97, blue: 0.95)
    let header = Color(red: 0.2, green: 0.35, blue: 0.2) // Dark Moss
    
    let primaryText = Color(red: 0.15, green: 0.2, blue: 0.15) // Darker green-black
    let secondaryText = Color(red: 0.3, green: 0.35, blue: 0.3).opacity(0.8)
    
    let sky = Color(red: 0.4, green: 0.6, blue: 0.7)
    let mint = Color(red: 0.25, green: 0.55, blue: 0.35)
    let peach = Color(red: 0.85, green: 0.65, blue: 0.45)
    let rose = Color(red: 0.75, green: 0.45, blue: 0.45)
    
    let iconName: String? = "AppIcon-Matcha"
}

/// A warm, dusk-inspired gradient theme.
struct SunsetTheme: AppTheme {
    let id = "sunset"
    let displayName = "Sunset"
    
    let background = Color(red: 0.18, green: 0.1, blue: 0.18) // Deep purple
    let radialCenter = Color(red: 0.3, green: 0.15, blue: 0.25)
    let radialEdge = Color(red: 0.1, green: 0.05, blue: 0.1)
    let accent = Color(red: 1.0, green: 0.65, blue: 0.25) // Brighter Orange
    // User Request: Keep paper color default
    let paper = Color(red: 0.98, green: 0.97, blue: 0.95)
    let header = Color(red: 1.0, green: 0.7, blue: 0.5) // Bright Peach
    
    let primaryText = Color(red: 0.98, green: 0.95, blue: 0.9) // Near white
    let secondaryText = Color(red: 1.0, green: 0.8, blue: 0.7).opacity(0.8)
    
    let sky = Color(red: 0.5, green: 0.4, blue: 0.7)
    let mint = Color(red: 0.3, green: 0.8, blue: 0.7)
    let peach = Color(red: 1.0, green: 0.55, blue: 0.35)
    let rose = Color(red: 1.0, green: 0.3, blue: 0.5)
    
    let iconName: String? = "AppIcon-Sunset"
}

/// A cool, icy minimalist theme.
struct NordicTheme: AppTheme {
    let id = "nordic"
    let displayName = "Nordic"
    
    let background = Color(red: 0.18, green: 0.20, blue: 0.25) // Polar Night
    let radialCenter = Color(red: 0.22, green: 0.24, blue: 0.30)
    let radialEdge = Color(red: 0.15, green: 0.17, blue: 0.22)
    let accent = Color(red: 0.53, green: 0.75, blue: 0.82) // Frost Blue
    // User Request: Keep paper color default
    let paper = Color(red: 0.98, green: 0.97, blue: 0.95)
    let header = Color(red: 0.7, green: 0.8, blue: 0.9) // Pale Frost Blue
    
    let primaryText = Color(red: 0.92, green: 0.94, blue: 0.96) // Snow Storm
    let secondaryText = Color(red: 0.75, green: 0.8, blue: 0.85).opacity(0.9)
    
    let sky = Color(red: 0.5, green: 0.7, blue: 0.9)
    let mint = Color(red: 0.6, green: 0.8, blue: 0.7)
    let peach = Color(red: 0.8, green: 0.6, blue: 0.5)
    let rose = Color(red: 0.75, green: 0.4, blue: 0.5)
    
    let iconName: String? = "AppIcon-Nordic"
}
