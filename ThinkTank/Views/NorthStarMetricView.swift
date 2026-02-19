import SwiftUI

/// Displays the North Star Metric: Structural Gravity + Directional Momentum.
///
/// Presented as two quiet ratio bars with descriptive labels.
/// This is NOT a score. It is a current-state indicator.
struct NorthStarMetricView: View {

    let gravity: Float          // density(core) × log(|core|), range ~[0, 3]
    let momentum: Float         // max momentum across emerging themes
    let densestThemeName: String?
    let densestThemeCount: Int
    let newestDirection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your thinking")
                .font(.headline)
                .foregroundStyle(.primary)

            // Gravity bar
            MetricBar(
                label: "Gravity",
                value: normalised(gravity, maxExpected: 3.0),
                displayValue: String(format: "%.2f", gravity),
                tint: .secondary
            )

            // Momentum bar
            MetricBar(
                label: "Momentum",
                value: normalised(momentum, maxExpected: 5.0),
                displayValue: String(format: "%.2f", momentum),
                tint: .accentColor.opacity(0.5)
            )

            // Descriptive labels
            if let theme = densestThemeName {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your densest area:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(theme) (\(densestThemeCount) ideas)")
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
            }

            if let direction = newestDirection {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Newest direction:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(direction)
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Normalise a value into [0, 1] for bar display, capping at an expected max.
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
                .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(value), height: 6)
                        .animation(.easeInOut(duration: 0.6), value: value)
                }
            }
            .frame(height: 6)

            Text(displayValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    NorthStarMetricView(
        gravity: 0.72,
        momentum: 0.31,
        densestThemeName: "distributed systems",
        densestThemeCount: 8,
        newestDirection: "error handling"
    )
    .padding()
}
