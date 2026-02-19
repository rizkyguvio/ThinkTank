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
        RapidCaptureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (RapidCaptureEntry) -> ()) {
        completion(RapidCaptureEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        completion(Timeline(entries: [RapidCaptureEntry(date: Date())], policy: .atEnd))
    }
}

struct RapidCaptureEntry: TimelineEntry {
    let date: Date
}

struct RapidCaptureWidgetView: View {
    var entry: RapidCaptureEntry

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.39, green: 0.40, blue: 0.95))
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.3), radius: 10, y: 5)
                
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Text("RIP IT")
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .containerBackground(for: .widget) {
            // Match the app's deep background
            Color(red: 0.06, green: 0.09, blue: 0.16)
        }
        .widgetURL(URL(string: "thinktank://capture"))
    }
}
