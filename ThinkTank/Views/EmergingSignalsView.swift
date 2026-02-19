import SwiftUI

/// Displays up to 3 emerging theme signals below the idea web.
///
/// Visual tone: calm, observational. Subtle upward arrow indicator,
/// muted colors, no celebration language.
struct EmergingSignalsView: View {

    let signals: [EmergingSignals.Signal]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emerging Signals")
                .font(.headline)
                .foregroundStyle(.primary)

            if signals.isEmpty {
                Text("No emerging patterns yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(signals) { signal in
                    SignalRow(signal: signal)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Signal row

private struct SignalRow: View {

    let signal: EmergingSignals.Signal

    /// Subtle repeating vertical drift.
    @State private var arrowOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .offset(y: arrowOffset)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true)
                    ) {
                        arrowOffset = -2
                    }
                }

            Text(signal.themeName)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Text("+\(String(format: "%.1f", signal.momentum))×")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    EmergingSignalsView(
        signals: [
            .init(themeName: "distributed systems", momentum: 2.3),
            .init(themeName: "API design", momentum: 1.8),
            .init(themeName: "error handling", momentum: 1.5),
        ]
    )
    .padding()
}
