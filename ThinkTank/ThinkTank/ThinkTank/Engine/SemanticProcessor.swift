import Foundation
import NaturalLanguage
import Accelerate

/// High-performance semantic engine for the Think Tank.
/// It uses Apple's NaturalLanguage framework for on-device
/// lemmatization, tokenization, and vector embeddings.
/// Cosine similarity uses vDSP (Accelerate framework) for SIMD-optimized computation.
nonisolated enum SemanticProcessor {
    
    /// Preprocesses text using NLTagger to extract base lemmas.
    /// This removes noise and normalizes terms ("ideas" -> "idea").
    static func preprocess(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var lemmas: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .lemma,
                             options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
            let lemma = tag?.rawValue ?? String(text[range]).lowercased()
            if lemma.count > 2 { // Filter out micro-words
                lemmas.append(lemma)
            }
            return true
        }
        return lemmas.joined(separator: " ")
    }
    
    /// Generates a semantic embedding vector for a piece of text.
    /// Uses Apple's sentence-level embedding for conceptual matching.
    static func generateEmbedding(for text: String) -> [Double]? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        return embedding.vector(for: text)
    }
    
    /// Calculates Cosine Similarity between two high-dimensional vectors.
    /// Range: [-1, 1]. High score (>0.75) indicates semantic parity.
    ///
    /// Uses Accelerate (vDSP) for SIMD-optimized dot product and magnitude computation.
    /// For the typical 512-dimensional NLEmbedding vectors, this is ~10x faster than a manual loop.
    static func cosineSimilarity(_ a: [Double]?, _ b: [Double]?) -> Double {
        guard let a = a, let b = b, a.count == b.count, !a.isEmpty else { return 0 }
        
        var dotProduct: Double = 0
        var magnitudeA: Double = 0
        var magnitudeB: Double = 0
        
        vDSP_dotprD(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotprD(a, 1, a, 1, &magnitudeA, vDSP_Length(a.count))
        vDSP_dotprD(b, 1, b, 1, &magnitudeB, vDSP_Length(b.count))
        
        let denom = sqrt(magnitudeA) * sqrt(magnitudeB)
        return denom == 0 ? 0 : dotProduct / denom
    }
}
