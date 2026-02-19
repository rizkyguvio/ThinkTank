import SwiftUI

/// A Canvas-based force-directed graph view of and idea's connections.
struct IdeaWebView: View {
    @ObservedObject var layout: ForceDirectedLayout
    @Binding var selection: Set<UUID>
    var onNodeTapped: (UUID) -> Void
    var onStarTapped: ((String) -> Void)? = nil // New: Galaxy navigation

    @State private var dragTargetID: UUID?
    @State private var ghostLink: (target: UUID, score: Float)?

    var body: some View {
        // Optimization: Pause the animation loop when physics is settled and user is not dragging.
        // This stops the 60fps redraws, saving massive CPU/battery.
        let isPaused = layout.isSettled && dragTargetID == nil
            
        TimelineView(.animation(paused: isPaused)) { timeline in
            Canvas { context, size in
                // 0. Draw Celestial Environment (Stars/Intents)
                let intents = IntentEngine.allIntentTags
                
                // OPTIMIZATION: Replaced expensive .blur() (9x per frame) with RadialGradient
                // Gaussian blur is O(radius × pixels), RadialGradient is O(pixels)
                for intent in intents {
                    let pos = layout.getCelestialPosition(for: intent)
                    let coronaRect = CGRect(x: pos.x - 45, y: pos.y - 45, width: 90, height: 90)
                    
                    let gradient = GraphicsContext.Shading.radialGradient(
                        Gradient(colors: [Pastel.accent.opacity(0.15), Pastel.accent.opacity(0.0)]),
                        center: CGPoint(x: 45, y: 45), // Relative to rect
                        startRadius: 10,
                        endRadius: 45
                    )
                    
                    // Use a separate layer for blending if needed, but fill directly is faster
                    var layerContext = context
                    layerContext.translateBy(x: coronaRect.minX, y: coronaRect.minY)
                    layerContext.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: 90, height: 90)), with: gradient)
                }

                // Draw Labels
                for intent in intents {
                    let pos = layout.getCelestialPosition(for: intent)
                    let text = Text(intent.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(Pastel.primaryText.opacity(0.8))
                    let resolved = context.resolve(text)
                    context.draw(resolved, at: CGPoint(x: pos.x, y: pos.y + 20), anchor: .top)
                }

                // 1. Draw Ghost Link (The "Predictive" Link)
                if let ghost = ghostLink, let source = layout.nodes[dragTargetID ?? UUID()], let target = layout.nodes[ghost.target] {
                    var path = Path()
                    path.move(to: source.position)
                    path.addLine(to: target.position)
                    context.stroke(
                        path,
                        with: .color(Pastel.accent.opacity(Double(ghost.score) * 0.4)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
                    )
                }

                // 2. Draw edges
                for (sourceID, neighbors) in layout.adjacency {
                    let sourceAlpha = layout.alpha(for: sourceID)
                    guard sourceAlpha > 0.05, let source = layout.nodes[sourceID] else { continue }
                    
                    for targetID in neighbors {
                        let targetAlpha = layout.alpha(for: targetID)
                        guard targetAlpha > 0.05, let target = layout.nodes[targetID] else { continue }
                        
                        var path = Path()
                        path.move(to: source.position)
                        path.addLine(to: target.position)
                        
                        context.stroke(
                            path,
                            with: .color(Pastel.accent.opacity(min(sourceAlpha, targetAlpha) * 0.15)),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                    }
                }

                // 3. Draw nodes
                for node in layout.nodes.values {
                    let alpha = layout.alpha(for: node.id)
                    guard alpha > 0.05 else { continue }
                    
                    let radius = node.radius
                    let rect = CGRect(x: node.position.x - radius, y: node.position.y - radius, width: radius * 2, height: radius * 2)

                    let isSelected = selection.contains(node.id)
                    let color = Pastel.color(for: node.status)
                    
                    // Highlight selected
                    if isSelected {
                        context.addFilter(.shadow(color: Pastel.accent.opacity(alpha), radius: 10))
                    } else if node.isCognitiveCore {
                        context.addFilter(.shadow(color: Pastel.accent.opacity(alpha * 0.3), radius: 6))
                    }

                    let nodePath = Path(ellipseIn: rect)
                    context.fill(nodePath, with: .color(color.opacity(alpha)))

                    if node.isCognitiveCore || isSelected {
                        context.stroke(nodePath, with: .color(isSelected ? Pastel.accent : Pastel.primaryText.opacity(alpha * 0.8)), lineWidth: isSelected ? 3 : 2)
                    }
                }
            }
            .onChange(of: timeline.date) { _, _ in
                layout.tick()
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newValue in
                layout.canvasSize = newValue
            }
        }
        .onTapGesture { location in
            if let id = findNode(at: location) {
                if selection.contains(id) {
                    selection.remove(id)
                } else {
                    if selection.count >= 2 { selection.removeAll() }
                    selection.insert(id)
                }
                onNodeTapped(id)
                HapticManager.shared.softTap()
                
                // Wake up simulation on interaction
                layout.isSettled = false
                
            } else if let intent = findStar(at: location) {
                onStarTapped?(intent)
                HapticManager.shared.triggerMediumImpact()
            } else {
                selection.removeAll()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if let id = dragTargetID ?? findNode(at: value.startLocation) {
                        dragTargetID = id
                        layout.nodes[id]?.position = value.location
                        layout.nodes[id]?.velocity = .zero
                        layout.isSettled = false // Keep simulation alive while dragging
                        
                        // Ghost Link Logic
                        updateGhostLink(for: id)
                        
                        // Haptic Gravity
                        if let node = layout.nodes[id], node.isCognitiveCore {
                            HapticManager.shared.dragPulse(intensity: 0.4)
                        }
                    }
                }
                .onEnded { _ in
                    dragTargetID = nil
                    ghostLink = nil
                    layout.isSettled = false // Let physics settle after drag release
                }
        )
    }

    private func findNode(at point: CGPoint) -> UUID? {
        for node in layout.nodes.values {
            let dx = node.position.x - point.x
            let dy = node.position.y - point.y
            if sqrt(dx*dx + dy*dy) < 25 { return node.id }
        }
        return nil
    }
    
    private func findStar(at point: CGPoint) -> String? {
        let intents = IntentEngine.allIntentTags
        for intent in intents {
            let pos = layout.getCelestialPosition(for: intent)
            let dx = pos.x - point.x
            let dy = pos.y - point.y
            if sqrt(dx*dx + dy*dy) < 40 { return intent }
        }
        return nil
    }

    private func updateGhostLink(for nodeID: UUID) {
        guard let sourceNode = layout.nodes[nodeID] else { return }
        
        var bestMatch: (UUID, Float)?
        let existingNeighbors = layout.adjacency[nodeID] ?? []
        
        for (otherID, otherNode) in layout.nodes where otherID != nodeID && !existingNeighbors.contains(otherID) {
            let dx = sourceNode.position.x - otherNode.position.x
            let dy = sourceNode.position.y - otherNode.position.y
            let dist = sqrt(dx*dx + dy*dy)
            
            if dist < 120 {
                let simulatedScore: Float = Float(1.0 - (dist / 120)) * 0.6
                if simulatedScore > (bestMatch?.1 ?? 0) {
                    bestMatch = (otherID, simulatedScore)
                }
            }
        }
        
        if let match = bestMatch, match.1 > 0.3 {
            if ghostLink?.target != match.0 {
                HapticManager.shared.lightTap()
            }
            ghostLink = match
        } else {
            ghostLink = nil
        }
    }
}
