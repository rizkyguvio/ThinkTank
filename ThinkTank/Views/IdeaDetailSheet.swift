import SwiftUI
import SwiftData

/// Bottom sheet shown when a node is tapped in the idea web.
struct IdeaDetailSheet: View {

    let idea: Idea
    let connectedIdeas: [Idea]

    /// Callback when user taps a connected idea to navigate to it.
    var onNavigate: ((UUID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Idea")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(idea.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Full content
            Text(idea.content)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Keywords
            if !idea.extractedKeywords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keywords")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(idea.extractedKeywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Color.secondary.opacity(0.1),
                                    in: Capsule()
                                )
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Connected ideas
            if !connectedIdeas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connected ideas")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(connectedIdeas) { connected in
                        Button {
                            onNavigate?(connected.id)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(.secondary.opacity(0.4))
                                    .frame(width: 6, height: 6)

                                Text(connected.content)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Simple flow layout for keyword pills

/// A basic horizontal flow layout that wraps to the next line.
struct FlowLayout: Layout {

    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                // Wrap to next line.
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }

        return LayoutResult(
            size: CGSize(width: totalWidth, height: y + lineHeight),
            positions: positions
        )
    }
}
