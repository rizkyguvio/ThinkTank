import SwiftUI
import SwiftData

/// The interactive idea web canvas.
///
/// Renders nodes as circles, edges as lines, and highlights the Cognitive Core.
/// Uses a `TimelineView` to drive the force-directed physics simulation at
/// display refresh rate until the layout settles.
struct IdeaWebView: View {

    @ObservedObject var layout: ForceDirectedLayout

    /// All edges as (source, target) pairs for line drawing.
    let edges: [(source: UUID, target: UUID)]

    /// Callback when a node is tapped.
    var onNodeTapped: ((UUID) -> Void)?

    /// Currently selected node ID.
    @Binding var selectedNodeID: UUID?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: layout.isSettled)) { _ in
            let _ = layout.tick()

            Canvas { context, size in
                layout.canvasSize = size
                drawEdges(context: context)
                drawNodes(context: context)
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleTap(at: value.location)
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { _ in
                        // Zoom handled externally via .scaleEffect
                    }
            )
        }
        .drawingGroup() // Flatten for Metal rendering — smoother perf.
    }

    // MARK: - Drawing

    private func drawEdges(context: GraphicsContext) {
        let nodes = layout.nodes

        for edge in edges {
            guard let source = nodes[edge.source],
                  let target = nodes[edge.target] else { continue }

            let isSelected = selectedNodeID == edge.source || selectedNodeID == edge.target
            let opacity: Double = selectedNodeID == nil ? 0.15 :
                                   isSelected ? 0.4 : 0.05

            var path = Path()
            path.move(to: source.position)
            path.addLine(to: target.position)

            context.stroke(
                path,
                with: .color(.secondary.opacity(opacity)),
                lineWidth: isSelected ? 1.5 : 0.5
            )
        }
    }

    private func drawNodes(context: GraphicsContext) {
        let allNodes = layout.nodes
        let hasCoreCluster = allNodes.values.contains { $0.isCognitiveCore }

        for node in allNodes.values {
            let isSelected = selectedNodeID == node.id
            let isConnectedToSelected: Bool = {
                guard let selID = selectedNodeID else { return false }
                return edges.contains { ($0.source == selID && $0.target == node.id) ||
                                        ($0.target == selID && $0.source == node.id) }
            }()

            // Determine opacity.
            let opacity: Double
            if selectedNodeID == nil {
                opacity = 1.0
            } else if isSelected || isConnectedToSelected {
                opacity = 1.0
            } else {
                opacity = 0.2
            }

            // Determine fill color.
            let fillColor: Color
            if node.isCognitiveCore {
                fillColor = .accentColor.opacity(0.6)
            } else {
                fillColor = .secondary.opacity(0.5)
            }

            // Scale on selection.
            let radius = node.radius * (isSelected ? 1.15 : 1.0)

            let rect = CGRect(
                x: node.position.x - radius,
                y: node.position.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            context.opacity = opacity
            context.fill(
                Path(ellipseIn: rect),
                with: .color(fillColor)
            )
            context.opacity = 1.0
        }
    }

    // MARK: - Hit testing

    private func handleTap(at location: CGPoint) {
        let hitRadius: CGFloat = 20

        // Find the closest node within hit radius.
        var closest: (id: UUID, dist: CGFloat)?

        for (id, node) in layout.nodes {
            let dx = location.x - node.position.x
            let dy = location.y - node.position.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist <= hitRadius {
                if closest == nil || dist < closest!.dist {
                    closest = (id, dist)
                }
            }
        }

        if let tapped = closest {
            HapticManager.shared.softTap()
            SoundManager.shared.playTapSound()
            withAnimation(.interpolatingSpring(stiffness: 80, damping: 14)) {
                selectedNodeID = tapped.id
            }
            onNodeTapped?(tapped.id)
        } else {
            // Tap on background → deselect.
            withAnimation(.interpolatingSpring(stiffness: 80, damping: 14)) {
                selectedNodeID = nil
            }
        }
    }
}
