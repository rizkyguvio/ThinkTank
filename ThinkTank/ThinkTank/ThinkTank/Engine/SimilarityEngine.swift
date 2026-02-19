import Foundation

/// Computes TF-IDF vectors and Semantic Cosine Similarity.
///
/// This engine is the hybrid brain of the Think Tank, combining 
/// lexical (TF-IDF) and semantic (Embeddings) bridges.
nonisolated enum SimilarityEngine {

    /// The minimum Weighted Jaccard score for two ideas to be lexically connected.
    static let lexicalThreshold: Float = 0.25

    /// The minimum Cosine Similarity score for a semantic bridge.
    static let semanticThreshold: Double = 0.72

    // MARK: - TF-IDF

    static func tfidfVector(
        keywords: [String],
        corpusDocumentFrequency: [String: Int],
        totalDocuments: Int
    ) -> [String: Float] {
        guard totalDocuments > 0 else { return [:] }
        let n = Float(max(totalDocuments, 1))
        var vector: [String: Float] = [:]
        var tf: [String: Int] = [:]
        for kw in keywords { tf[kw, default: 0] += 1 }
        for (kw, count) in tf {
            let termFreq = Float(count) / Float(keywords.count)
            let docFreq = Float(corpusDocumentFrequency[kw] ?? 0)
            let idf = log(n / (docFreq + 1))
            vector[kw] = termFreq * idf
        }
        return vector
    }

    // MARK: - Weighted Jaccard

    static func weightedJaccard(
        _ vectorA: [String: Float],
        _ vectorB: [String: Float]
    ) -> Float {
        let allKeys = Set(vectorA.keys).union(vectorB.keys)
        guard !allKeys.isEmpty else { return 0 }
        var numerator: Float = 0
        var denominator: Float = 0
        for key in allKeys {
            let wA = vectorA[key] ?? 0
            let wB = vectorB[key] ?? 0
            numerator += min(wA, wB)
            denominator += max(wA, wB)
        }
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    // MARK: - Batch edge computation

    /// Lexical search: Matching distinct keywords.
    static func computeLexicalEdges(
        newVector: [String: Float],
        candidates: [(id: UUID, vector: [String: Float])],
        threshold: Float = lexicalThreshold
    ) -> [(targetID: UUID, score: Float)] {
        candidates.compactMap { candidate in
            let score = weightedJaccard(newVector, candidate.vector)
            return score >= threshold ? (candidate.id, score) : nil
        }
    }

    /// Semantic search: Matching high-level conceptual meaning.
    static func computeSemanticEdges(
        newEmbedding: [Double],
        candidates: [(id: UUID, embedding: [Double])],
        threshold: Double = semanticThreshold
    ) -> [(targetID: UUID, score: Float)] {
        candidates.compactMap { candidate in
            let score = SemanticProcessor.cosineSimilarity(newEmbedding, candidate.embedding)
            return score >= threshold ? (candidate.id, Float(score)) : nil
        }
    }
}
