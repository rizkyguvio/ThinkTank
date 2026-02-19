import SwiftUI
import SwiftData

/// The "Think Tank" brain visualization page.
struct AnalyticsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @Query private var edges: [GraphEdge]
    @Query private var themes: [Theme]

    @Binding var tabOpacity: Double

    @StateObject private var layout = ForceDirectedLayout()
    @State private var selectedIdea: Idea?
    
    // Computed metrics for North Star & Signals
    @State private var gravity: Float = 0
    @State private var momentum: Float = 0
    @State private var densestThemeName: String?
    @State private var densestThemeCount: Int = 0
    @State private var newestDirection: String?
    @State private var signals: [EmergingSignals.Signal] = []
    
    // New: Insight & Narrative state
    @State private var fadingInterests: [EmergingSignals.Signal] = []
    @State private var crossPollinations: [GraphEngine.CrossPollinationInsight] = []
    @State private var timeProgress: Double = 1.0 // 0 to 1 for scrubber

    @State private var selection = Set<UUID>()
    @State private var synthesisResult: SynthesisEngine.SynthesisResult?
    @State private var unlinkedPairs: [(Idea, Idea, Double)] = []

    private var activeIdeas: [Idea] {
        ideas.filter { $0.status != .archived }
    }

    var body: some View {
        ZStack {
            Pastel.radialBackground
            
            ScrollView {
                VStack(spacing: 0) { // Spacing handled individually
                    // Section 1: Live Mind State
                    liveMindStateSection
                        .padding(.top, 60)
                        .padding(.bottom, 32)
                    
                    // Section 2: Time Lens
                    timeLensSection
                        .padding(.bottom, 24)
                    
                    // Section 3: Cognitive Forces
                    cognitiveForcesSection
                        .padding(.bottom, 24)
                    
                    // NEW: Synthesis Playground
                    SynthesisPlaygroundView(unlinkedSimilarPairs: unlinkedPairs) { a, b in
                        selection = [a.id, b.id]
                    }
                    .padding(.bottom, 32)
                    
                    // Section 4: Directional Shifts
                    directionalShiftsSection
                        .padding(.bottom, 24)
                    
                    insightsSection
                        .padding(.bottom, 40)
                    
                    Spacer(minLength: 120)
                }
            }

            // High Fidelity Overlay: Cognitive Collider
            if let result = synthesisResult {
                cognitiveColliderPanel(for: result)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedIdea) { idea in detailSheetView(for: idea) }
        .onAppear {
            refreshLayout()
            migrateLegacyIdeas()
        }
        .onChange(of: ideas) { _, _ in refreshLayout() }
        .onChange(of: timeProgress) { _, newValue in
            updateTimeFilter(progress: newValue)
        }
        .onChange(of: selection) { _, newSelection in
            updateSynthesis(for: newSelection)
            withAnimation {
                tabOpacity = newSelection.isEmpty ? 1.0 : 0.0
            }
        }
        .onDisappear {
            withAnimation { tabOpacity = 1.0 }
        }
    }

    // MARK: - Subviews

    private func SectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .kerning(4)
                .foregroundStyle(Pastel.header) // High contrast headers
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var graphHeader: some View {
        HStack {
            Spacer()
            if layout.focusNodeIDs != nil || !selection.isEmpty {
                Button(selection.isEmpty ? "Reset Focus" : "Clear Selection") {
                    withAnimation { 
                        layout.focusNodeIDs = nil
                        selection.removeAll()
                    }
                    HapticManager.shared.softTap()
                }
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Pastel.accent.opacity(0.15)))
                .foregroundStyle(Pastel.accent)
            }
        }
        .padding(.horizontal, 24).padding(.top, 16)
    }

    private var liveMindStateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("LIVE MIND STATE")
            
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Pastel.primaryText.opacity(Pastel.current.id == "paper_theme" ? 0.04 : 0.015))

                    IdeaWebView(layout: layout, selection: $selection) { id in
                        if let idea = ideas.first(where: { $0.id == id }) {
                            selectedIdea = idea
                        }
                    } onStarTapped: { theme in
                        focusOnTheme(theme)
                    }
                    
                    // Reset/Clear buttons overlay
                    if layout.focusNodeIDs != nil || !selection.isEmpty {
                        graphResetButton.padding(16)
                    }
                }
                .frame(height: 400)
                
                Text("\(activeIdeas.count) active concepts")
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Pastel.primaryText.opacity(0.15))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var graphResetButton: some View {
        Button(selection.isEmpty ? "Reset Focus" : "Clear Selection") {
            withAnimation { 
                layout.focusNodeIDs = nil
                selection.removeAll()
            }
            HapticManager.shared.softTap()
        }
        .font(.system(size: 10, weight: .bold))
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(Pastel.accent.opacity(0.15)))
        .foregroundStyle(Pastel.accent)
    }

    private var timeLensSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("TIME LENS")
            
            HStack(spacing: 16) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Pastel.primaryText.opacity(0.2))
                
                Slider(value: $timeProgress, in: 0...1)
                    .tint(Pastel.accent)
                
                Text(dateString(for: timeProgress))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Pastel.accent.opacity(0.6))
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Pastel.primaryText.opacity(0.02)))
            .padding(.horizontal, 16)
        }
    }
    
    private var cognitiveForcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("COGNITIVE FORCES")
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Your Thinking")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Pastel.header) // Increased contrast
                
                VStack(spacing: 16) {
                    MetricForceBar(label: "Clarity Core", value: gravity, maxValue: 3.0, tint: Pastel.accent)
                    MetricForceBar(label: "Inspiration Flow", value: momentum, maxValue: 5.0, tint: Pastel.mint)
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24).fill(Pastel.primaryText.opacity(0.02)))
            .padding(.horizontal, 16)
        }
    }
    
    private var directionalShiftsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("DIRECTIONAL SHIFTS")
            
            VStack(alignment: .leading, spacing: 0) {
                // Primary Line: Newest Direction
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Newest Direction")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Pastel.header.opacity(0.6))
                        Text(newestDirection ?? "Stabilizing")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Pastel.primaryText)
                    }
                    Spacer()
                    Text("Rising")
                        .font(.system(size: 8, weight: .bold)) // Even smaller
                        .padding(.horizontal, 6).padding(.vertical, 2) // Tighter padding
                        .background(Capsule().fill(Pastel.mint.opacity(0.15)))
                        .foregroundStyle(Pastel.mint)
                }
                .padding(20)
                
                Divider().background(Pastel.primaryText.opacity(0.05)).padding(.horizontal, 20)
                
                // Emerging Signals List
                VStack(spacing: 12) {
                    if signals.isEmpty {
                        Text("Equilibrium maintained.")
                            .font(.system(size: 11))
                            .foregroundStyle(Pastel.primaryText.opacity(0.15))
                    } else {
                        ForEach(signals.prefix(3)) { signal in
                            HStack {
                                Text(signal.themeName)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Pastel.primaryText.opacity(0.8))
                                Spacer()
                                Text("+\(Int(signal.momentum))x")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Pastel.peach.opacity(0.8)) // Reduced opacity for secondary
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(RoundedRectangle(cornerRadius: 24).fill(Pastel.primaryText.opacity(0.02)))
            .padding(.horizontal, 16)
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("COGNITIVE INSIGHTS")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Missed Connections
                    ForEach(Array(crossPollinations.enumerated()), id: \.offset) { _, insight in
                        InsightCard(
                            title: "Missed Connection?",
                            message: "Your thoughts on '\(insight.themeA)' and '\(insight.themeB)' are isolated. Is there a link?",
                            icon: "bolt.horizontal.circle.fill",
                            color: Pastel.sky
                        ) {
                            focusOn(ids: insight.clusterA + insight.clusterB)
                        }
                    }
                    
                    // Fading Interests
                    ForEach(fadingInterests) { signal in
                        InsightCard(
                            title: "Fading Interest",
                            message: "You haven't added to your '\(signal.themeName)' core recently. Revisit?",
                            icon: "leaf.fill",
                            color: Pastel.peach
                        ) {
                            focusOnTheme(signal.themeName)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // Removed metricsSection as its components are integrated into forces/shifts

    // MARK: - Logic

    private func refreshLayout() {
        let currentIdeas = ideas.filter { $0.status != .archived }
        let activeIDs = Set(currentIdeas.map(\.id))
        let activeIDsArray = Array(activeIDs)
        
        // Pre-build UUID→Idea dictionary for O(1) lookups (used multiple times below)
        let ideaByID: [UUID: Idea] = Dictionary(
            currentIdeas.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        // Build adjacency from edges
        var adj: [UUID: Set<UUID>] = [:]
        for edge in edges {
            guard let source = edge.sourceIdea, activeIDs.contains(source.id), activeIDs.contains(edge.targetIdeaID) else { continue }
            adj[source.id, default: []].insert(edge.targetIdeaID)
            adj[edge.targetIdeaID, default: []].insert(source.id)
        }

        let centrality = GraphEngine.degreeCentrality(nodeIDs: activeIDsArray, adjacency: adj)
        let clusters = GraphEngine.findClusters(nodeIDs: activeIDsArray, adjacency: adj)
        
        var coreNodes: Set<UUID> = []
        var calculatedGravity: Float = 0
        var calculatedThemeName: String?
        var calculatedThemeCount: Int = 0
        
        if let coreResult = GraphEngine.findCognitiveCore(clusters: clusters, ideas: currentIdeas) {
            coreNodes = Set(coreResult.clusterNodeIDs)
            calculatedGravity = coreResult.score
            calculatedThemeCount = coreResult.clusterNodeIDs.count
            
            // Use O(1) dictionary lookup instead of O(n) .first(where:)
            var tagCounts: [String: Int] = [:]
            for nodeID in coreResult.clusterNodeIDs {
                if let idea = ideaByID[nodeID] {
                    for tag in idea.themeTags { tagCounts[tag, default: 0] += 1 }
                }
            }
            calculatedThemeName = tagCounts.max(by: { $0.value < $1.value })?.key
        }

        let calculatedSignals = EmergingSignals.detect(themes: themes, ideas: currentIdeas)
        let calculatedMomentum = calculatedSignals.map(\.momentum).max() ?? 0
        let calculatedDirection = calculatedSignals.first?.themeName
        
        let calculatedFading = EmergingSignals.detectFading(themes: themes, ideas: currentIdeas)
        let calculatedIsolated = GraphEngine.findIsolatedPairs(clusters: clusters, adjacency: adj)

        // Build intent map using lowercased Set for O(1) matching
        // instead of O(ideas × intents) with localizedCaseInsensitiveCompare
        let intentTagsLower = Set(IntentEngine.allIntentTags.map { $0.lowercased() })
        let intentTagsOriginal: [String: String] = Dictionary(
            IntentEngine.allIntentTags.map { ($0.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        var intentMap: [UUID: [String]] = [:]
        for idea in currentIdeas {
            var matches: [String] = []
            for tag in idea.themeTags {
                let lower = tag.lowercased()
                if intentTagsLower.contains(lower), let original = intentTagsOriginal[lower] {
                    matches.append(original)
                }
            }
            if !matches.isEmpty { intentMap[idea.id] = matches }
        }

        self.gravity = calculatedGravity
        self.momentum = calculatedMomentum
        self.densestThemeName = calculatedThemeName
        self.densestThemeCount = calculatedThemeCount
        self.newestDirection = calculatedDirection
        self.signals = calculatedSignals
        self.fadingInterests = calculatedFading
        self.crossPollinations = calculatedIsolated
        
        // Synthesis Playground: Find similar-but-unconnected idea pairs
        var pairs: [(Idea, Idea, Double)] = []
        let recentIdeas = currentIdeas.prefix(30)
        
        for i in 0..<recentIdeas.count {
            for j in (i+1)..<recentIdeas.count {
                let ideaA = recentIdeas[i]
                let ideaB = recentIdeas[j]
                
                let isConnected = adj[ideaA.id]?.contains(ideaB.id) ?? false
                if !isConnected {
                    if let embA = ideaA.embedding, let embB = ideaB.embedding {
                        let score = SemanticProcessor.cosineSimilarity(embA, embB)
                        if score > 0.65 && score < 0.95 {
                            pairs.append((ideaA, ideaB, score))
                        }
                    }
                }
                if pairs.count >= 10 { break }
            }
            if pairs.count >= 10 { break }
        }
        self.unlinkedPairs = pairs.sorted { $0.2 > $1.2 }
        
        layout.configure(
            ideas: currentIdeas,
            adjacency: adj,
            centrality: centrality,
            cognitiveCore: coreNodes,
            clusters: clusters,
            intentMap: intentMap
        )
    }

    private func updateTimeFilter(progress: Double) {
        let dates = ideas.map(\.createdAt)
        guard let minDate = dates.min(), let maxDate = dates.max() else { return }
        let totalSpan = maxDate.timeIntervalSince(minDate)
        let cutoff = minDate.addingTimeInterval(totalSpan * progress)
        layout.timeCutoff = cutoff
    }

    private func focusOn(ids: [UUID]) {
        withAnimation { layout.focusNodeIDs = Set(ids) }
        HapticManager.shared.triggerMediumImpact()
    }

    private func focusOnTheme(_ theme: String) {
        let ids = ideas.filter { $0.themeTags.contains(theme) }.map(\.id)
        focusOn(ids: ids)
    }

    private func dateString(for progress: Double) -> String {
        let dates = ideas.map(\.createdAt)
        guard let minDate = dates.min(), let maxDate = dates.max() else { return "Present" }
        let totalSpan = maxDate.timeIntervalSince(minDate)
        let date = minDate.addingTimeInterval(totalSpan * progress)
        let formatter = DateFormatter(); formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func migrateLegacyIdeas() {
        let legacy = ideas.filter { $0.embedding == nil }
        guard !legacy.isEmpty else { return }
        
        Task {
            for idea in legacy {
                idea.embedding = SemanticProcessor.generateEmbedding(for: idea.content)
            }
            try? modelContext.save()
            refreshLayout()
        }
    }

    private func updateSynthesis(for selection: Set<UUID>) {
        if selection.count == 2 {
            let selectedIDs = Array(selection)
            if let ideaA = ideas.first(where: { $0.id == selectedIDs[0] }),
               let ideaB = ideas.first(where: { $0.id == selectedIDs[1] }) {
                withAnimation(.spring()) {
                    synthesisResult = SynthesisEngine.synthesize(ideaA, ideaB)
                }
                HapticManager.shared.triggerMediumImpact()
            }
        } else {
            withAnimation { synthesisResult = nil }
        }
    }

    private func deepenStudy(for result: SynthesisEngine.SynthesisResult) {
        let ids = Array(selection)
        guard ids.count == 2 else { return }
        
        // Create the new synthetic thought
        let synthesisHeader = "✨ BRAIN SYNTHESIS: \(result.prompt)"
        let fullContent = "\(synthesisHeader)\n\n\(result.insight)"
        
        let newIdea = Idea(content: fullContent)
        newIdea.themeTags = ["Synthesis"]
        newIdea.status = .active
        
        // Generate embedding immediately for the new synthesis
        newIdea.embedding = SemanticProcessor.generateEmbedding(for: fullContent)
        
        modelContext.insert(newIdea)
        
        // Solidify the bridge: Create edges to both parents
        for sourceID in ids {
            let edge = GraphEdge(source: newIdea, targetID: sourceID, score: result.confidence)
            modelContext.insert(edge)
        }
        
        try? modelContext.save()
        
        // Feedback loop
        withAnimation {
            selection.removeAll()
            HapticManager.shared.ripItSuccess()
        }
        
        // Show the newly born idea
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedIdea = newIdea
            refreshLayout()
        }
    }

    @ViewBuilder
    private func cognitiveColliderPanel(for result: SynthesisEngine.SynthesisResult) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Pastel.accent, Pastel.sky], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .symbolEffect(.pulse, options: .repeating)
                    
                    Text("Brain Synthesis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Pastel.primaryText)
                    
                    Spacer()
                    
                    Button { withAnimation { selection.removeAll() } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Pastel.primaryText.opacity(0.3)).font(.title2)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(result.prompt)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(Pastel.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(result.insight)
                        .font(.system(size: 14))
                        .foregroundStyle(Pastel.primaryText.opacity(0.7))
                        .lineSpacing(4)
                }
                
                HStack {
                    Label("\(Int(result.confidence * 100))% Semantic Match", systemImage: "brain.head.profile")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Pastel.accent)
                    Spacer()
                    Button("Deepen Study") { 
                        deepenStudy(for: result)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(Pastel.accent))
                    .foregroundStyle(Pastel.current.id == "paper_theme" ? .white : .black)
                }
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(LinearGradient(colors: [Pastel.accent.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
            }
            .padding(16)
            .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 20)
        }
    }

    private func fetchConnected(for idea: Idea) -> [Idea] {
        let currentActiveIDs = Set(activeIdeas.map(\.id))
        let targetIDs = edges.filter { $0.sourceIdea?.id == idea.id }.map { $0.targetIdeaID }.filter { currentActiveIDs.contains($0) }
        return ideas.filter { targetIDs.contains($0.id) }
    }

    @ViewBuilder
    private func detailSheetView(for idea: Idea) -> some View {
        IdeaDetailSheet(
            idea: idea,
            connectedIdeas: fetchConnected(for: idea)
        ) { targetID in
            if let next = ideas.first(where: { $0.id == targetID }) {
                selectedIdea = next
            }
        }
    }
}

// MARK: - Sub-Components

struct MetricForceBar: View {
    let label: String
    let value: Float
    let maxValue: Float
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Pastel.header.opacity(0.5)) // Standardized contrast
                Spacer()
                // Increased contrast on numbers, reduced precision
                Text("\(Int(value))") 
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Pastel.primaryText)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Pastel.primaryText.opacity(0.04))
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(min(max(value / maxValue, 0), 1)))
                }
            }
            .frame(height: 12) // Thicker bars (approx 15% increase from previous 8-10)
        }
    }
}

struct InsightCard: View {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon).foregroundStyle(color).font(.system(size: 18))
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Pastel.header)
                }
                Text(message).font(.system(size: 12)).foregroundStyle(Pastel.primaryText.opacity(0.5)).lineLimit(3).multilineTextAlignment(.leading)
            }
            .frame(width: 220, height: 120, alignment: .topLeading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Pastel.primaryText.opacity(0.1), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }
}
