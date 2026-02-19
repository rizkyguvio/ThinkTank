import Foundation

/// Computes TF-IDF vectors and Weighted Jaccard similarity between keyword sets.
///
/// TF-IDF weights suppress common words ("idea", "think") and amplify
/// distinctive terms, giving the similarity algorithm semantic discrimination.
enum SimilarityEngine {

    /// The minimum Weighted Jaccard score for two ideas to be connected.
    ///
    /// Set to 0.12 (down from 0.25) so that edges form at small corpus sizes (~15 ideas).
    /// At 15 notes, TF-IDF vectors are sparse and Jaccard scores cluster near zero —
    /// a 0.25 threshold was too aggressive. 0.12 still rejects noise while allowing
    /// real topical overlap to register.
    static let edgeThreshold: Float = 0.12

    // MARK: - TF-IDF

    /// Compute a TF-IDF weight vector for a set of keywords.
    ///
    /// - Parameters:
    ///   - keywords: The keywords of the idea being scored.
    ///   - corpusDocumentFrequency: `[keyword: number_of_documents_containing_it]`
    ///     across the entire idea corpus.
    ///   - totalDocuments: Total number of ideas in the corpus.
    /// - Returns: `[keyword: weight]` dictionary.
    static func tfidfVector(
        keywords: [String],
        corpusDocumentFrequency: [String: Int],
        totalDocuments: Int
    ) -> [String: Float] {
        guard totalDocuments > 0 else { return [:] }

        let n = Float(max(totalDocuments, 1))
        var vector: [String: Float] = [:]

        // Term frequency within this idea (simple count).
        var tf: [String: Int] = [:]
        for kw in keywords {
            tf[kw, default: 0] += 1
        }

        for (kw, count) in tf {
            let termFreq = Float(count) / Float(keywords.count)
            let docFreq = Float(corpusDocumentFrequency[kw] ?? 0)
            // +1 smoothing to avoid log(0)
            let idf = log(n / (docFreq + 1))
            vector[kw] = termFreq * idf
        }

        return vector
    }

    // MARK: - Weighted Jaccard

    /// Compute the Weighted Jaccard similarity between two TF-IDF vectors.
    ///
    /// ```
    /// similarity(A, B) =
    ///     Î£ min(w_A(k), w_B(k))  for k âˆˆ keys_A âˆª keys_B
    ///     â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    ///     Î£ max(w_A(k), w_B(k))  for k âˆˆ keys_A âˆª keys_B
    /// ```
    ///
    /// Range: [0, 1]. Returns 0 if both vectors are empty.
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

    /// Compare a new idea's vector against a list of candidates and return
    /// edges that meet the threshold.
    ///
    /// - Returns: Array of `(candidateID, score)` tuples.
    static func computeEdges(
        newVector: [String: Float],
        candidates: [(id: UUID, vector: [String: Float])],
        threshold: Float = edgeThreshold
    ) -> [(targetID: UUID, score: Float)] {
        candidates.compactMap { candidate in
            let score = weightedJaccard(newVector, candidate.vector)
            return score >= threshold ? (candidate.id, score) : nil
        }
    }
}
