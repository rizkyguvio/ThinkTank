import Foundation

/// Pure graph algorithms for the idea web: cluster detection, density,
/// centrality, and Cognitive Core identification.
///
/// All methods are static and operate on adjacency structures — they do not
/// touch SwiftData directly.
nonisolated enum GraphEngine {

    /// Adjacency list representation for fast lookups.
    typealias AdjacencyList = [UUID: Set<UUID>]

    // MARK: - Adjacency construction

    /// Build a bidirectional adjacency list from a list of edges.
    static func buildAdjacency(
        from edges: [(source: UUID, target: UUID)]
    ) -> AdjacencyList {
        var adj: AdjacencyList = [:]
        adj.reserveCapacity(edges.count)
        for edge in edges {
            adj[edge.source, default: []].insert(edge.target)
            adj[edge.target, default: []].insert(edge.source)
        }
        return adj
    }

    // MARK: - Connected components (cluster detection)

    /// Find all connected components with ≥ 2 nodes.
    /// Solo nodes (degree 0) are excluded — they are not clusters.
    static func findClusters(
        nodeIDs: [UUID],
        adjacency: AdjacencyList
    ) -> [[UUID]] {
        var visited = Set<UUID>()
        visited.reserveCapacity(nodeIDs.count)
        var clusters: [[UUID]] = []

        for nodeID in nodeIDs where !visited.contains(nodeID) {
            var component: [UUID] = []
            var queue: [UUID] = [nodeID]

            while !queue.isEmpty {
                let current = queue.removeFirst()
                guard !visited.contains(current) else { continue }
                visited.insert(current)
                component.append(current)

                if let neighbors = adjacency[current] {
                    for neighbor in neighbors where !visited.contains(neighbor) {
                        queue.append(neighbor)
                    }
                }
            }

            if component.count >= 2 {
                clusters.append(component)
            }
        }

        return clusters
    }

    /// Compute semantic density of a cluster.
    ///
    /// Calculates the average semantic similarity between all pairs in the cluster.
    /// Returns 0 for clusters with fewer than 2 nodes.
    ///
    /// Optimized: Uses a UUID→embedding dictionary for O(1) lookups instead of O(n) array filtering.
    /// Caps pairwise computation to first 50 nodes to bound worst-case from O(n²) to O(2500).
    static func semanticDensity(
        clusterNodeIDs: [UUID],
        ideas: [Idea]
    ) -> Float {
        let n = clusterNodeIDs.count
        guard n >= 2 else { return 0 }

        // Build a lookup dictionary for O(1) access instead of O(n) linear scan
        let idSet = Set(clusterNodeIDs)
        let embeddings: [UUID: [Double]] = {
            var map: [UUID: [Double]] = [:]
            map.reserveCapacity(min(n, 50))
            for idea in ideas {
                guard idSet.contains(idea.id), let emb = idea.embedding else { continue }
                map[idea.id] = emb
                if map.count >= 50 { break } // Cap for performance
            }
            return map
        }()
        
        let keys = Array(embeddings.keys)
        guard keys.count >= 2 else { return 0 }
        
        var totalSimilarity: Double = 0
        var pairCount = 0

        for i in 0..<keys.count {
            guard let embA = embeddings[keys[i]] else { continue }
            for j in (i + 1)..<keys.count {
                guard let embB = embeddings[keys[j]] else { continue }
                totalSimilarity += SemanticProcessor.cosineSimilarity(embA, embB)
                pairCount += 1
            }
        }

        return pairCount > 0 ? Float(totalSimilarity) / Float(pairCount) : 0
    }

    // MARK: - Cognitive Core

    /// Result of identifying the densest, most substantial cluster.
    struct CognitiveCore {
        let clusterNodeIDs: [UUID]
        let density: Float
        let score: Float  // density × log(n)
    }

    /// Identify the Cognitive Core — the cluster with the highest
    /// `semanticDensity × log(count)` score.
    static func findCognitiveCore(
        clusters: [[UUID]],
        ideas: [Idea]
    ) -> CognitiveCore? {
        guard !clusters.isEmpty else { return nil }

        var best: CognitiveCore?

        for cluster in clusters {
            let d = semanticDensity(clusterNodeIDs: cluster, ideas: ideas)
            let score = d * log(Float(cluster.count))

            if best == nil || score > best!.score {
                best = CognitiveCore(
                    clusterNodeIDs: cluster,
                    density: d,
                    score: score
                )
            }
        }

        return best
    }

    // MARK: - Advanced Insights
    
    /// Result of an insight query.
    struct CrossPollinationInsight {
        let clusterA: [UUID]
        let clusterB: [UUID]
        let themeA: String
        let themeB: String
    }
    
    /// Find pairs of clusters that have NO edges between them.
    /// This is used to suggest "Missed Connections".
    static func findIsolatedPairs(
        clusters: [[UUID]],
        adjacency: AdjacencyList
    ) -> [CrossPollinationInsight] {
        guard clusters.count >= 2 else { return [] }
        
        var insights: [CrossPollinationInsight] = []
        // We only check the top 4 clusters to avoid insight overload.
        let topClusters = clusters.sorted(by: { $0.count > $1.count }).prefix(4)
        
        for i in 0..<topClusters.count {
            for j in (i + 1)..<topClusters.count {
                let clusterA = topClusters[i]
                let clusterB = topClusters[j]
                
                // Check if any node in A connects to any node in B
                let setB = Set(clusterB)
                let hasConnection = clusterA.contains { nodeA in
                    adjacency[nodeA]?.isDisjoint(with: setB) == false
                }
                
                if !hasConnection {
                    insights.append(CrossPollinationInsight(
                        clusterA: clusterA,
                        clusterB: clusterB,
                        themeA: "Cluster \(i+1)",
                        themeB: "Cluster \(j+1)"
                    ))
                }
            }
        }
        return insights
    }

    // MARK: - Degree centrality

    /// Compute degree centrality for every node.
    static func degreeCentrality(
        nodeIDs: [UUID],
        adjacency: AdjacencyList
    ) -> [UUID: Float] {
        let n = nodeIDs.count
        guard n > 1 else { return [:] }

        let maxDegree = Float(n - 1)
        var result: [UUID: Float] = [:]
        result.reserveCapacity(n)

        for id in nodeIDs {
            let degree = adjacency[id]?.count ?? 0
            result[id] = Float(degree) / maxDegree
        }

        return result
    }
}
