import SwiftUI

/// Displays the North Star Metric: Structural Gravity + Directional Momentum.
///
/// Scales its messaging with corpus size — early users see something useful
/// rather than two empty bars and an unexplained "Stabilizing" label.
struct NorthStarMetricView: View {

    let gravity: Float          // density(core) × log(|core|), scaled to ~[0, 3]
    let momentum: Float         // max momentum across emerging themes
    let densestThemeName: String?
    let densestThemeCount: Int
    let newestDirection: String?

    // Optional context — passed in so the view can show corpus-aware copy
    var totalIdeas: Int = 0
    var totalEdges: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your thinking")
                .font(.headline)
                .foregroundStyle(.primary)

            // Clarity Core bar
            MetricBar(
                label: "Clarity Core",
                value: normalised(gravity, maxExpected: 3.0),
                displayValue: gravityLabel,
                tint: .secondary
            )

            // Inspiration Flow bar
            MetricBar(
                label: "Inspiration Flow",
                value: normalised(momentum, maxExpected: 5.0),
                displayValue: momentumLabel,
                tint: .accentColor.opacity(0.5)
            )

            // Most active theme — always shows something once any ideas exist
            if let theme = densestThemeName {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Most active theme")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(theme) · \(densestThemeCount) idea\(densestThemeCount == 1 ? "" : "s")")
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
            }

            // Directional shift — honest nil handling instead of "Stabilizing"
            VStack(alignment: .leading, spacing: 4) {
                Text("Directional shift")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let direction = newestDirection {
                    Text(direction)
                        .font(.callout)
                        .foregroundStyle(.primary)
                } else {
                    Text(noDirectionCopy)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            // Connectivity hint — only shown when no edges have formed yet
            if totalEdges == 0 && totalIdeas >= 3 {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                    Text("Connections form when ideas share themes. Keep capturing — your graph will light up soon.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed labels

    /// Human-readable Clarity Core label — never shows a raw "0.00"
    private var gravityLabel: String {
        if gravity < 0.05 { return "forming" }
        if gravity < 0.8  { return "building" }
        if gravity < 2.0  { return "strong" }
        return "dense"
    }

    /// Human-readable Inspiration Flow label
    private var momentumLabel: String {
        if momentum < 0.3 { return "quiet" }
        if momentum < 1.0 { return "rising" }
        if momentum < 2.5 { return "surging" }
        return "peaking"
    }

    /// Context-aware copy when no directional signal exists
    private var noDirectionCopy: String {
        switch totalIdeas {
        case 0:       return "No ideas yet"
        case 1..<5:   return "Capture a few more to see patterns"
        case 5..<15:  return "Patterns taking shape…"
        default:      return "No strong shift right now"
        }
    }

    private func normalised(_ value: Float, maxExpected: Float) -> Float {
        min(max(value / maxExpected, 0), 1)
    }
}

// MARK: - Metric bar

private struct MetricBar: View {

    let label: String
    let value: Float   // [0, 1]
    let displayValue: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint)
                        // Minimum visible width of 4pt so the bar is never invisible at tiny values
                        .frame(width: max(geo.size.width * CGFloat(value), value > 0 ? 4 : 0), height: 6)
                        .animation(.easeInOut(duration: 0.6), value: value)
                }
            }
            .frame(height: 6)

            Text(displayValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Small corpus — what user sees at 15 notes
        NorthStarMetricView(
            gravity: 0.04,
            momentum: 0.0,
            densestThemeName: "Creative",
            densestThemeCount: 4,
            newestDirection: nil,
            totalIdeas: 15,
            totalEdges: 0
        )

        // Mature corpus
        NorthStarMetricView(
            gravity: 1.4,
            momentum: 2.1,
            densestThemeName: "distributed systems",
            densestThemeCount: 8,
            newestDirection: "error handling",
            totalIdeas: 60,
            totalEdges: 34
        )
    }
    .padding()
}
