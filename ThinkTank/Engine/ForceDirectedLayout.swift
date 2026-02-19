import Foundation
import SwiftUI

/// A node in the force-directed graph layout, with position, velocity,
/// and visual properties computed from centrality.
struct LayoutNode: Identifiable {
    let id: UUID
    var position: CGPoint
    var velocity: CGPoint = .zero

    /// Degree centrality [0, 1] — drives visual radius.
    var centrality: Float = 0

    /// Whether this node belongs to the Cognitive Core cluster.
    var isCognitiveCore: Bool = false

    /// Which cluster index this node belongs to (nil if isolated).
    var clusterIndex: Int?

    /// Display radius, computed from centrality. Range [4, 12].
    var radius: CGFloat {
        let base: CGFloat = 4
        let scale: CGFloat = 8
        return base + scale * CGFloat(centrality)
    }
}

/// Fruchterman-Reingold force-directed layout engine.
///
/// Produces a stable, calm arrangement of nodes where connected ideas
/// cluster together organically. Runs iteratively; call `tick()` per frame.
final class ForceDirectedLayout: ObservableObject {

    // MARK: - Published state

    @Published var nodes: [UUID: LayoutNode] = [:]
    @Published var isSettled: Bool = false

    // MARK: - Configuration

    /// Repulsive constant multiplier.
    private let repulsionStrength: CGFloat = 800

    /// Attraction constant (edge spring).
    private let attractionStrength: CGFloat = 0.006

    /// Gentle pull toward center to prevent drift.
    private let gravityStrength: CGFloat = 0.01

    /// Velocity damping per tick. 0.85 → settles in ~40 frames.
    private let damping: CGFloat = 0.85

    /// Kinetic energy threshold below which the simulation is "settled".
    private let settleThreshold: CGFloat = 0.5

    /// Canvas size (viewport).
    var canvasSize: CGSize = CGSize(width: 400, height: 400)

    // MARK: - Graph data

    private var adjacency: GraphEngine.AdjacencyList = [:]

    // MARK: - Setup

    /// Initialise or reset the layout with new graph data.
    ///
    /// New nodes are placed randomly within the canvas. Existing nodes
    /// retain their positions (incremental layout on new idea).
    func configure(
        nodeIDs: [UUID],
        adjacency: GraphEngine.AdjacencyList,
        centrality: [UUID: Float],
        cognitiveCore: Set<UUID>,
        clusters: [[UUID]]
    ) {
        self.adjacency = adjacency

        // Map cluster membership.
        var clusterMap: [UUID: Int] = [:]
        for (index, cluster) in clusters.enumerated() {
            for id in cluster { clusterMap[id] = index }
        }

        // Add new nodes, preserve existing positions.
        for id in nodeIDs {
            if nodes[id] == nil {
                let x = CGFloat.random(in: 40...(canvasSize.width - 40))
                let y = CGFloat.random(in: 40...(canvasSize.height - 40))
                nodes[id] = LayoutNode(
                    id: id,
                    position: CGPoint(x: x, y: y),
                    centrality: centrality[id] ?? 0,
                    isCognitiveCore: cognitiveCore.contains(id),
                    clusterIndex: clusterMap[id]
                )
            } else {
                nodes[id]?.centrality = centrality[id] ?? 0
                nodes[id]?.isCognitiveCore = cognitiveCore.contains(id)
                nodes[id]?.clusterIndex = clusterMap[id]
            }
        }

        // Remove nodes no longer in the graph.
        let validIDs = Set(nodeIDs)
        nodes = nodes.filter { validIDs.contains($0.key) }

        isSettled = false
    }

    // MARK: - Simulation tick

    /// Advance the simulation by one frame. Call from a `CADisplayLink` or
    /// `TimelineView` at 60 fps.
    func tick() {
        guard !isSettled else { return }

        let allIDs = Array(nodes.keys)
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        var forces: [UUID: CGPoint] = [:]
        for id in allIDs { forces[id] = .zero }

        // 1. Repulsion between all pairs.
        for i in 0..<allIDs.count {
            for j in (i + 1)..<allIDs.count {
                let idA = allIDs[i], idB = allIDs[j]
                guard let a = nodes[idA], let b = nodes[idB] else { continue }

                var dx = a.position.x - b.position.x
                var dy = a.position.y - b.position.y
                let dist = max(sqrt(dx * dx + dy * dy), 1)

                let force = repulsionStrength / (dist * dist)
                dx = dx / dist * force
                dy = dy / dist * force

                forces[idA]?.x += dx
                forces[idA]?.y += dy
                forces[idB]?.x -= dx
                forces[idB]?.y -= dy
            }
        }

        // 2. Attraction along edges.
        for (source, neighbors) in adjacency {
            guard let sNode = nodes[source] else { continue }
            for target in neighbors {
                guard let tNode = nodes[target] else { continue }

                let dx = tNode.position.x - sNode.position.x
                let dy = tNode.position.y - sNode.position.y
                let dist = max(sqrt(dx * dx + dy * dy), 1)

                let force = dist * dist * attractionStrength
                let fx = dx / dist * force
                let fy = dy / dist * force

                forces[source]?.x += fx
                forces[source]?.y += fy
                // The reverse is handled when we iterate the other direction.
            }
        }

        // 3. Gravity toward center.
        for id in allIDs {
            guard let node = nodes[id] else { continue }
            let dx = center.x - node.position.x
            let dy = center.y - node.position.y
            forces[id]?.x += dx * gravityStrength
            forces[id]?.y += dy * gravityStrength
        }

        // 4. Apply forces, dampen, clamp to canvas.
        var totalKineticEnergy: CGFloat = 0

        for id in allIDs {
            guard var node = nodes[id], let f = forces[id] else { continue }

            node.velocity.x = (node.velocity.x + f.x) * damping
            node.velocity.y = (node.velocity.y + f.y) * damping

            node.position.x += node.velocity.x
            node.position.y += node.velocity.y

            // Clamp within canvas bounds with padding.
            let pad: CGFloat = 20
            node.position.x = max(pad, min(canvasSize.width - pad, node.position.x))
            node.position.y = max(pad, min(canvasSize.height - pad, node.position.y))

            totalKineticEnergy += node.velocity.x * node.velocity.x
                                + node.velocity.y * node.velocity.y

            nodes[id] = node
        }

        if totalKineticEnergy < settleThreshold {
            isSettled = true
        }
    }
}
