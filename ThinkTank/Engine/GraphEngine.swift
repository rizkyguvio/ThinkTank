import Foundation

/// Pure graph algorithms for the idea web: cluster detection, density,
/// centrality, and Cognitive Core identification.
///
/// All methods are static and operate on adjacency structures — they do not
/// touch SwiftData directly.
enum GraphEngine {

    /// Adjacency list representation for fast lookups.
    typealias AdjacencyList = [UUID: Set<UUID>]

    // MARK: - Adjacency construction

    /// Build a bidirectional adjacency list from a list of edges.
    static func buildAdjacency(
        from edges: [(source: UUID, target: UUID)]
    ) -> AdjacencyList {
        var adj: AdjacencyList = [:]
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

    // MARK: - Density

    /// Compute edge density of a cluster.
    ///
    /// `density = 2e / (n × (n − 1))`  where n = node count, e = edge count.
    /// Returns 0 for clusters with fewer than 2 nodes.
    static func density(
        cluster: [UUID],
        adjacency: AdjacencyList
    ) -> Float {
        let n = cluster.count
        guard n >= 2 else { return 0 }

        let clusterSet = Set(cluster)
        var edgeCount = 0

        for node in cluster {
            guard let neighbors = adjacency[node] else { continue }
            for neighbor in neighbors where clusterSet.contains(neighbor) {
                edgeCount += 1
            }
        }

        // Each edge counted twice (once from each end).
        let e = edgeCount / 2
        let maxEdges = n * (n - 1) / 2
        return Float(e) / Float(maxEdges)
    }

    // MARK: - Cognitive Core

    /// Result of identifying the densest, most substantial cluster.
    struct CognitiveCore {
        let clusterNodeIDs: [UUID]
        let density: Float
        let score: Float  // density × log(n)
    }

    /// Identify the Cognitive Core — the cluster with the highest
    /// `density × log(count)` score.
    ///
    /// Returns `nil` if there are no clusters.
    static func findCognitiveCore(
        clusters: [[UUID]],
        adjacency: AdjacencyList
    ) -> CognitiveCore? {
        guard !clusters.isEmpty else { return nil }

        var best: CognitiveCore?

        for cluster in clusters {
            let d = density(cluster: cluster, adjacency: adjacency)
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

    // MARK: - Degree centrality

    /// Compute degree centrality for every node.
    ///
    /// `centrality(node) = degree(node) / (N − 1)` where N = total node count.
    /// Returns empty dictionary if N ≤ 1.
    static func degreeCentrality(
        nodeIDs: [UUID],
        adjacency: AdjacencyList
    ) -> [UUID: Float] {
        let n = nodeIDs.count
        guard n > 1 else { return [:] }

        let maxDegree = Float(n - 1)
        var result: [UUID: Float] = [:]

        for id in nodeIDs {
            let degree = adjacency[id]?.count ?? 0
            result[id] = Float(degree) / maxDegree
        }

        return result
    }
}
