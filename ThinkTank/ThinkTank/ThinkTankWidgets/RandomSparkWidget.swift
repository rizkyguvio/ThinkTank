import WidgetKit
import SwiftUI
import SwiftData

struct RandomSparkProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> RandomSparkEntry {
        RandomSparkEntry(date: Date(), content: "Capture a thought to see it here.", theme: "Reflection", themeId: "classic")
    }

    func getSnapshot(in context: Context, completion: @escaping (RandomSparkEntry) -> ()) {
        let entry = RandomSparkEntry(date: Date(), content: "The beauty of a thought is in its connection.", theme: "Synthesis", themeId: "classic")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [RandomSparkEntry] = []
        let currentDate = Date()
        let appGroup = "group.personal.ThinkTank.Gio"
        
        var isConfigured = false
        if let _ = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            isConfigured = true
        }
        
        // Fetch a random idea from SwiftData
        let idea = fetchRandomIdea()
        let themeId = UserDefaults(suiteName: appGroup)?.string(forKey: "ThinkTank_SelectedTheme") ?? "classic"
        
        // Show error if not configured, otherwise normal content
        let entry = RandomSparkEntry(
            date: currentDate,
            content: idea?.content ?? "Capture a thought to see it here.",
            theme: idea?.themeTags.first ?? "Think Tank",
            themeId: themeId,
            isError: !isConfigured
        )
        entries.append(entry)

        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchRandomIdea() -> Idea? {
        let schema = Schema([Idea.self, Theme.self, GraphEdge.self])
        let appGroup = "group.personal.ThinkTank.Gio"
        
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return nil
        }
        
        let storeURL = groupURL.appendingPathComponent("ThinkTank.sqlite")
        let config = ModelConfiguration(url: storeURL)
        
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return nil
        }
        
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Idea>()
        let ideas = (try? context.fetch(descriptor)) ?? []
        return ideas.shuffled().first
    }
}

struct RandomSparkEntry: TimelineEntry {
    let date: Date
    let content: String
    let theme: String
    let themeId: String
    var isError: Bool = false
}

struct RandomSparkWidgetView : View {
    var entry: RandomSparkProvider.Entry
    @Environment(\.widgetFamily) var family

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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Text("THINK TANK")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(2.0)
                        .foregroundStyle(headerColor)
                    
                    Spacer()
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(accentColor.opacity(0.6))
                }
                .padding(.bottom, 10)
                
                // Content
                Text(entry.content)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(primaryTextColor)
                    .lineSpacing(1.5)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Footer (Theme)
                if !entry.theme.isEmpty {
                    HStack {
                        Text(entry.theme.uppercased())
                            .font(.system(size: 7, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Spacer()
                    }
                }
            }
            .padding(14)
            .containerBackground(for: .widget) {
                backgroundColor
            }
        }
    }
    
    // Dynamic Theme Helper for Widget UI
    private var backgroundColor: Color {
        switch entry.themeId {
        case "midnight":    return Color(red: 0.01, green: 0.02, blue: 0.04)
        case "studio":      return Color(red: 0.17, green: 0.15, blue: 0.13)
        case "paper_theme": return Color(red: 0.98, green: 0.976, blue: 0.965)
        case "neon":        return Color(red: 0.05, green: 0.05, blue: 0.08)
        case "matcha":      return Color(red: 0.94, green: 0.96, blue: 0.94)
        case "sunset":      return Color(red: 0.18, green: 0.1, blue: 0.18)
        case "nordic":      return Color(red: 0.18, green: 0.20, blue: 0.25)
        default:            return Color(red: 0.06, green: 0.09, blue: 0.16) // Classic
        }
    }
    
    private var headerColor: Color {
        if entry.themeId == "paper_theme" || entry.themeId == "matcha" { return Color.black.opacity(0.4) }
        return Color.white.opacity(0.3)
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
    
    private var primaryTextColor: Color {
        if entry.themeId == "paper_theme" || entry.themeId == "matcha" { return Color(red: 0.15, green: 0.15, blue: 0.18) }
        return Color.white.opacity(0.9)
    }
}

struct RandomSparkWidget: Widget {
    let kind: String = "RandomSparkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RandomSparkProvider()) { entry in
            RandomSparkWidgetView(entry: entry)
        }
        .configurationDisplayName("Random Spark")
        .description("Passive serendipity from your past thoughts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
