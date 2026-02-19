import WidgetKit
import SwiftUI
import AppIntents

struct RapidCaptureWidget: Widget {
    let kind: String = "RapidCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RapidCaptureProvider()) { entry in
            RapidCaptureWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Capture")
        .description("Rip a thought immediately.")
        .supportedFamilies([.systemSmall])
    }
}

struct RapidCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> RapidCaptureEntry {
        RapidCaptureEntry(date: Date(), themeId: "classic")
    }

    func getSnapshot(in context: Context, completion: @escaping (RapidCaptureEntry) -> ()) {
        completion(RapidCaptureEntry(date: Date(), themeId: "classic"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let appGroup = "group.personal.ThinkTank.Gio"
        var isConfigured = false
        
        if let _ = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            isConfigured = true
        }
        
        let themeId = UserDefaults(suiteName: appGroup)?.string(forKey: "ThinkTank_SelectedTheme") ?? "classic"
        
        // If not configured (no entitlements), show error state
        let entry = RapidCaptureEntry(
            date: Date(), 
            themeId: themeId,
            isError: !isConfigured
        )
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct RapidCaptureEntry: TimelineEntry {
    let date: Date
    let themeId: String
    var isError: Bool = false
}

struct RapidCaptureWidgetView: View {
    var entry: RapidCaptureEntry

    var body: some View {
        if entry.isError {
             VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                Text("App Group Missing")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Add 'group.personal.ThinkTank.Gio' in Xcode Capabilities")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .containerBackground(for: .widget) { Color.red.opacity(0.8) }
        } else {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: accentColor.opacity(0.3), radius: 10, y: 5)
                    
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                
                Text("RIP IT")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(headerColor)
            }
            .containerBackground(for: .widget) {
                backgroundColor
            }
            .widgetURL(URL(string: "thinktank://capture"))
        }
    }
    
    private var backgroundColor: Color {
        switch entry.themeId {
        case "midnight":    return Color(red: 0.01, green: 0.02, blue: 0.04)
        case "studio":      return Color(red: 0.17, green: 0.15, blue: 0.13)
        case "paper_theme": return Color(red: 0.98, green: 0.976, blue: 0.965)
        case "neon":        return Color(red: 0.05, green: 0.05, blue: 0.08)
        case "matcha":      return Color(red: 0.94, green: 0.96, blue: 0.94)
        case "sunset":      return Color(red: 0.18, green: 0.1, blue: 0.18)
        case "nordic":      return Color(red: 0.18, green: 0.20, blue: 0.25)
        default:            return Color(red: 0.06, green: 0.09, blue: 0.16)
        }
    }
    
    private var accentColor: Color {
        switch entry.themeId {
        case "midnight":    return Color(red: 0.23, green: 0.51, blue: 0.96)
        case "studio":      return Color(red: 0.85, green: 0.47, blue: 0.03)
        case "neon":        return Color(red: 0.0, green: 1.0, blue: 0.8)
        case "matcha":      return Color(red: 0.4, green: 0.55, blue: 0.3)
        case "sunset":      return Color(red: 1.0, green: 0.6, blue: 0.2)
        case "nordic":      return Color(red: 0.53, green: 0.75, blue: 0.82)
        default:            return Color(red: 0.39, green: 0.40, blue: 0.95)
        }
    }
    
    private var iconColor: Color {
        if entry.themeId == "neon" { return .black }
        return .white
    }
    
    private var headerColor: Color {
        if entry.themeId == "paper_theme" || entry.themeId == "matcha" { return Color.black.opacity(0.6) }
        if entry.themeId == "neon" { return Color.white.opacity(0.9) }
        return .white.opacity(0.6)
    }
}
