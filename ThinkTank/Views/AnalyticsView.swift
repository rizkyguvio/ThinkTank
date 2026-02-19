import SwiftUI
import SwiftData

/// The main Analytics page — orchestrates the idea web, emerging signals,
/// and north star metric.
///
/// This is the primary view the user sees when navigating to the Analytics tab.
/// The idea web is the FIRST and PRIMARY element, filling most of the viewport.
struct AnalyticsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @Query private var themes: [Theme]
    @Query private var allEdges: [GraphEdge]

    @StateObject private var layout = ForceDirectedLayout()

    @State private var selectedNodeID: UUID?
    @State private var selectedIdea: Idea?
    @State private var showDetailSheet = false
    @State private var zoomScale: CGFloat = 1.0

    // Computed graph data — recomputed when ideas/edges change.
    private var graphData: GraphSnapshot {
        computeGraph()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // ─── Idea Web (primary) ───
                ideaWebSection

                // ─── North Star Metric ───
                if !ideas.isEmpty {
                    NorthStarMetricView(
                        gravity: graphData.gravity,
                        momentum: graphData.topMomentum,
                        densestThemeName: graphData.densestThemeName,
                        densestThemeCount: graphData.densestThemeCount,
                        newestDirection: graphData.newestDirection
                    )
                    .padding(.horizontal)
                }

                // ─── Emerging Signals ───
                EmergingSignalsView(signals: graphData.emergingSignals)
                    .padding(.horizontal)

                Spacer(minLength: 32)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDetailSheet) {
            if let idea = selectedIdea {
                IdeaDetailSheet(
                    idea: idea,
                    connectedIdeas: connectedIdeas(for: idea.id),
                    onNavigate: { targetID in
                        showDetailSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedNodeID = targetID
                            if let target = ideas.first(where: { $0.id == targetID }) {
                                selectedIdea = target
                                showDetailSheet = true
                            }
                        }
                    }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .graphDidUpdate)) { _ in
            refreshLayout()
        }
        .onAppear {
            refreshLayout()
        }
        .onChange(of: showDetailSheet) { _, isShowing in
            if isShowing {
                HapticManager.shared.lightTap()
            }
        }
    }

    // MARK: - Idea web section

    private var ideaWebSection: some View {
        VStack(spacing: 8) {
            if ideas.isEmpty {
                emptyState
            } else {
                IdeaWebView(
                    layout: layout,
                    edges: graphData.edgePairs,
                    onNodeTapped: { nodeID in
                        selectedIdea = ideas.first { $0.id == nodeID }
                        showDetailSheet = selectedIdea != nil
                    },
                    selectedNodeID: $selectedNodeID
                )
                .frame(height: 420)
                .scaleEffect(zoomScale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoomScale = min(max(value, 0.5), 3.0)
                        }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Node count label
                Text("\(ideas.count) ideas")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.grid.3x3")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)

            Text("Your idea web will appear here")
                .font(.callout)
                .foregroundStyle(.tertiary)

            Text("Capture ideas with Rip It to begin.")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Graph computation

    private struct GraphSnapshot {
        let edgePairs: [(source: UUID, target: UUID)]
        let gravity: Float
        let topMomentum: Float
        let densestThemeName: String?
        let densestThemeCount: Int
        let newestDirection: String?
        let emergingSignals: [EmergingSignals.Signal]
    }

    private func computeGraph() -> GraphSnapshot {
        // Build edge pairs from SwiftData edges.
        let pairs: [(source: UUID, target: UUID)] = allEdges.compactMap { edge in
            guard let sourceID = edge.sourceIdea?.id else { return nil }
            return (sourceID, edge.targetIdeaID)
        }

        let nodeIDs = ideas.map(\.id)
        let adjacency = GraphEngine.buildAdjacency(from: pairs)
        let clusters = GraphEngine.findClusters(nodeIDs: nodeIDs, adjacency: adjacency)
        let core = GraphEngine.findCognitiveCore(clusters: clusters, adjacency: adjacency)

        // Gravity
        let gravity = core?.score ?? 0

        // Emerging signals
        let signals = EmergingSignals.detect(themes: themes, ideas: ideas)
        let topMomentum = signals.first?.momentum ?? 0
        let newestDirection = signals.first?.themeName

        // Densest theme name — pick the most common tag in the core cluster.
        var densestThemeName: String?
        var densestThemeCount = 0
        if let coreIDs = core?.clusterNodeIDs {
            densestThemeCount = coreIDs.count
            let coreIDSet = Set(coreIDs)
            var tagCounts: [String: Int] = [:]
            for idea in ideas where coreIDSet.contains(idea.id) {
                for tag in idea.themeTags {
                    tagCounts[tag, default: 0] += 1
                }
            }
            densestThemeName = tagCounts.max(by: { $0.value < $1.value })?.key
        }

        return GraphSnapshot(
            edgePairs: pairs,
            gravity: gravity,
            topMomentum: topMomentum,
            densestThemeName: densestThemeName,
            densestThemeCount: densestThemeCount,
            newestDirection: newestDirection,
            emergingSignals: signals
        )
    }

    // MARK: - Layout refresh

    private func refreshLayout() {
        let nodeIDs = ideas.map(\.id)
        let pairs: [(source: UUID, target: UUID)] = allEdges.compactMap { edge in
            guard let sourceID = edge.sourceIdea?.id else { return nil }
            return (sourceID, edge.targetIdeaID)
        }
        let adjacency = GraphEngine.buildAdjacency(from: pairs)
        let centrality = GraphEngine.degreeCentrality(nodeIDs: nodeIDs, adjacency: adjacency)
        let clusters = GraphEngine.findClusters(nodeIDs: nodeIDs, adjacency: adjacency)
        let core = GraphEngine.findCognitiveCore(clusters: clusters, adjacency: adjacency)

        layout.configure(
            nodeIDs: nodeIDs,
            adjacency: adjacency,
            centrality: centrality,
            cognitiveCore: Set(core?.clusterNodeIDs ?? []),
            clusters: clusters
        )
    }

    // MARK: - Connected ideas lookup

    private func connectedIdeas(for ideaID: UUID) -> [Idea] {
        var connectedIDs = Set<UUID>()

        for edge in allEdges {
            if edge.sourceIdea?.id == ideaID {
                connectedIDs.insert(edge.targetIdeaID)
            } else if edge.targetIdeaID == ideaID, let sourceID = edge.sourceIdea?.id {
                connectedIDs.insert(sourceID)
            }
        }

        return ideas.filter { connectedIDs.contains($0.id) }
    }
}
