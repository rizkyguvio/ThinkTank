import WidgetKit
import SwiftUI
import SwiftData

struct RandomSparkProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> RandomSparkEntry {
        RandomSparkEntry(date: Date(), content: "Capture a thought to see it here.", theme: "Reflection")
    }

    func getSnapshot(in context: Context, completion: @escaping (RandomSparkEntry) -> ()) {
        let entry = RandomSparkEntry(date: Date(), content: "The beauty of a thought is in its connection.", theme: "Synthesis")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [RandomSparkEntry] = []
        let currentDate = Date()
        
        // Fetch a random idea from SwiftData
        let idea = fetchRandomIdea()
        
        let entry = RandomSparkEntry(
            date: currentDate,
            content: idea?.content ?? "Capture a thought to see it here.",
            theme: idea?.themeTags.first ?? "Think Tank"
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
}

struct RandomSparkWidgetView : View {
    var entry: RandomSparkProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Text("THINK TANK")
                    .font(.system(size: 9, weight: .bold)) // Adjusted for fit
                    .kerning(2.0)
                    .foregroundStyle(.black.opacity(0.3))
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.6))
            }
            .padding(.bottom, 10)
            
            // Content
            Text(entry.content)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(.black.opacity(0.85))
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
                        .foregroundStyle(Color(red: 0.39, green: 0.40, blue: 0.95))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Spacer()
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            // Clean "Premium Paper" look - No lines, just texture/tone
            Color(red: 0.99, green: 0.98, blue: 0.97)
        }
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
