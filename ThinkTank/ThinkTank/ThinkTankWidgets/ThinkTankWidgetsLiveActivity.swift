//
//  ThinkTankWidgetsLiveActivity.swift
//  ThinkTankWidgets
//
//  Created by Gio on 19/02/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ThinkTankWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ThinkTankWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ThinkTankWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ThinkTankWidgetsAttributes {
    fileprivate static var preview: ThinkTankWidgetsAttributes {
        ThinkTankWidgetsAttributes(name: "World")
    }
}

extension ThinkTankWidgetsAttributes.ContentState {
    fileprivate static var smiley: ThinkTankWidgetsAttributes.ContentState {
        ThinkTankWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ThinkTankWidgetsAttributes.ContentState {
         ThinkTankWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ThinkTankWidgetsAttributes.preview) {
   ThinkTankWidgetsLiveActivity()
} contentStates: {
    ThinkTankWidgetsAttributes.ContentState.smiley
    ThinkTankWidgetsAttributes.ContentState.starEyes
}
