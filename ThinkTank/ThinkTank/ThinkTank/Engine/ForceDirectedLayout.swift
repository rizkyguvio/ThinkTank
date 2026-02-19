import Foundation
import SwiftUI
import Combine

// MARK: - Updated Node
nonisolated struct LayoutNode: Identifiable, Sendable {
    let id: UUID
    var position: CGPoint
    var velocity: CGPoint = .zero
    var centrality: Float = 0
    var status: IdeaStatus = .active
    var isCognitiveCore: Bool = false
    var clusterIndex: Int?
    var intents: [String] = [] // New: Semantic anchors
    var createdAt: Date = .now // Temporal tracker

    var radius: CGFloat {
        let base: CGFloat = 5
        let scale: CGFloat = 8
        return base + scale * CGFloat(centrality)
    }
}

@MainActor
final class ForceDirectedLayout: ObservableObject {
    @Published var nodes: [UUID: LayoutNode] = [:]
    @Published var isSettled: Bool = false
    
    // New: Filter states for Narrative view
    @Published var timeCutoff: Date = .distantFuture
    @Published var focusNodeIDs: Set<UUID>? = nil

    private let repulsionStrength: CGFloat = 800
    private let attractionStrength: CGFloat = 0.006
    private let gravityStrength: CGFloat = 0.01
    private let damping: CGFloat = 0.85
    private let settleThreshold: CGFloat = 0.5
    var canvasSize: CGSize = CGSize(width: 400, height: 400)
    private(set) var adjacency: [UUID: Set<UUID>] = [:]

    func configure(
        ideas: [Idea],
        adjacency: [UUID: Set<UUID>],
        centrality: [UUID: Float],
        cognitiveCore: Set<UUID>,
        clusters: [[UUID]],
        intentMap: [UUID: [String]] = [:]
    ) {
        self.adjacency = adjacency
        var clusterMap: [UUID: Int] = [:]
        for (index, cluster) in clusters.enumerated() {
            for id in cluster { clusterMap[id] = index }
        }

        for idea in ideas {
            let id = idea.id
            if nodes[id] == nil {
                let x = CGFloat.random(in: 40...(canvasSize.width - 40))
                let y = CGFloat.random(in: 40...(canvasSize.height - 40))
                nodes[id] = LayoutNode(
                    id: id,
                    position: CGPoint(x: x, y: y),
                    centrality: centrality[id] ?? 0,
                    status: idea.status,
                    isCognitiveCore: cognitiveCore.contains(id),
                    clusterIndex: clusterMap[id],
                    intents: intentMap[id] ?? [],
                    createdAt: idea.createdAt
                )
            } else {
                nodes[id]?.centrality = centrality[id] ?? 0
                nodes[id]?.status = idea.status
                nodes[id]?.isCognitiveCore = cognitiveCore.contains(id)
                nodes[id]?.clusterIndex = clusterMap[id]
                nodes[id]?.createdAt = idea.createdAt
            }
        }
        let ideaIDs = Set(ideas.map(\.id))
        nodes = nodes.filter { ideaIDs.contains($0.key) }
        isSettled = false
    }

    /// Calculate combined opacity for immersive filtering
    func alpha(for nodeID: UUID) -> Double {
        guard let node = nodes[nodeID] else { return 0 }
        
        // Narrative: Time Filter
        if node.createdAt > timeCutoff { return 0 }
        
        // Focus: Isolation Filter
        if let focus = focusNodeIDs {
            return focus.contains(nodeID) ? 1.0 : 0.15
        }
        
        return 1.0
    }

    func tick() {
        guard !isSettled else { return }
        
        // Performance Optimization: Only simulate visible nodes.
        // O(N^2) is unsustainable at 10,000 nodes. Pruning to current 'Focus' or 'Temporal' window.
        let visibleIDs = nodes.keys.filter { alpha(for: $0) > 0.01 }
        
        // Hard safety limit: Never simulate more than 400 nodes simultaneously to protect main thread.
        // Prioritize nodes with higher centrality if we exceed this.
        let simulationIDs: [UUID]
        if visibleIDs.count > 400 {
            simulationIDs = visibleIDs.sorted { (nodes[$0]?.centrality ?? 0) > (nodes[$1]?.centrality ?? 0) }.prefix(400).map { $0 }
        } else {
            simulationIDs = Array(visibleIDs)
        }

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        var forces: [UUID: CGPoint] = [:]
        for id in simulationIDs { forces[id] = .zero }

        // 1. Repulsion (Spatial Pruning applied)
        for i in 0..<simulationIDs.count {
            for j in (i + 1)..<simulationIDs.count {
                let idA = simulationIDs[i], idB = simulationIDs[j]
                guard let a = nodes[idA], let b = nodes[idB] else { continue }
                var dx = a.position.x - b.position.x
                var dy = a.position.y - b.position.y
                let distSq = max(dx * dx + dy * dy, 100) // Lower bound to prevent infinite force
                let dist = sqrt(distSq)
                let force = repulsionStrength / distSq
                dx = dx / dist * force
                dy = dy / dist * force
                forces[idA]?.x += dx
                forces[idA]?.y += dy
                forces[idB]?.x -= dx
                forces[idB]?.y -= dy
            }
        }

        // 2. Attraction & Gravity (Simulation subset only)
        for (source, neighbors) in adjacency {
            guard simulationIDs.contains(source), let sNode = nodes[source] else { continue }
            for target in neighbors {
                guard simulationIDs.contains(target), let tNode = nodes[target] else { continue }
                let dx = tNode.position.x - sNode.position.x
                let dy = tNode.position.y - sNode.position.y
                let dist = max(sqrt(dx * dx + dy * dy), 1)
                let force = dist * dist * attractionStrength
                forces[source]?.x += dx / dist * force
                forces[source]?.y += dy / dist * force
            }
        }

        for id in simulationIDs {
            guard let node = nodes[id] else { continue }
            
            // a. Standard global gravity (Pulls to center)
            forces[id]?.x += (center.x - node.position.x) * gravityStrength
            forces[id]?.y += (center.y - node.position.y) * gravityStrength
            
            // b. Celestial Gravity (Pulls to Intent Stars)
            if let firstIntent = node.intents.first {
                let target = getCelestialPosition(for: firstIntent)
                forces[id]?.x += (target.x - node.position.x) * (gravityStrength * 1.5)
                forces[id]?.y += (target.y - node.position.y) * (gravityStrength * 1.5)
            }
        }

        var totalKineticEnergy: CGFloat = 0
        for id in simulationIDs {
            guard var node = nodes[id], let f = forces[id] else { continue }
            node.velocity.x = (node.velocity.x + f.x) * damping
            node.velocity.y = (node.velocity.y + f.y) * damping
            node.position.x += node.velocity.x
            node.position.y += node.velocity.y
            node.position.x = max(20, min(canvasSize.width - 20, node.position.x))
            node.position.y = max(20, min(canvasSize.height - 20, node.position.y))
            totalKineticEnergy += node.velocity.x * node.velocity.x + node.velocity.y * node.velocity.y
            nodes[id] = node
        }
        if totalKineticEnergy < settleThreshold { isSettled = true }
    }

    private var celestialCache: [String: CGPoint] = [:]
    private var lastCanvasSize: CGSize = .zero

    /// Calculates the position of the "Star" for a given intent.
    /// Cached to avoid thousands of redundant cos/sin calls per second.
    func getCelestialPosition(for intent: String) -> CGPoint {
        // Rebuild cache if canvas resized
        if canvasSize != lastCanvasSize {
             celestialCache.removeAll()
             lastCanvasSize = canvasSize
        }
        
        if let cached = celestialCache[intent] { return cached }
        
        let intents = IntentEngine.allIntentTags
        guard let index = intents.firstIndex(of: intent) else { 
            let center = CGPoint(x: canvasSize.width/2, y: canvasSize.height/2)
            celestialCache[intent] = center
            return center
        }
        
        // Distribute stars in a circle
        let angle = Double(index) * (Double.pi * 2 / Double(max(intents.count, 1)))
        let distance = Double(min(canvasSize.width, canvasSize.height)) * 0.35
        
        let x = canvasSize.width / 2 + CGFloat(cos(angle) * distance)
        let y = canvasSize.height / 2 + CGFloat(sin(angle) * distance)
        let point = CGPoint(x: x, y: y)
        
        celestialCache[intent] = point
        return point
    }
}
