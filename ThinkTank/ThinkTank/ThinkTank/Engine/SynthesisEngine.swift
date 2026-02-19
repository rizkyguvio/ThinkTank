import Foundation
import NaturalLanguage

/// Apple Intelligence-inspired engine for synthesizing ideas.
/// It uses semantic intersection and thematic bridging to generate 
/// high-fidelity "Cognitive Prompts".
nonisolated enum SynthesisEngine {

    struct SynthesisResult: Identifiable {
        let id = UUID()
        let prompt: String
        let insight: String
        let confidence: Float
    }

    /// Generates a synthesis prompt between two ideas using semantic vectors.
    static func synthesize(_ ideaA: Idea, _ ideaB: Idea) -> SynthesisResult {
        let similarity = SemanticProcessor.cosineSimilarity(ideaA.embedding, ideaB.embedding)
        
        let keywordsA = Set(ideaA.extractedKeywords)
        let keywordsB = Set(ideaB.extractedKeywords)
        let intersection = keywordsA.intersection(keywordsB)
        
        let themesA = Set(ideaA.themeTags)
        let themesB = Set(ideaB.themeTags)
        let sharedThemes = themesA.intersection(themesB)
        
        // 1. Semantic High-Fidelity Match (Conceptual Parity)
        if similarity > 0.85 {
            return SynthesisResult(
                prompt: "Conceptual Parity Detected",
                insight: "These thoughts are semantically identical despite different phrasing. You are reinforcing a core belief about '\(sharedThemes.first ?? "this concept")'. Is this a mental breakthrough or a recurring loop?",
                confidence: Float(similarity)
            )
        }

        // 2. Direct Thematic Connection
        if !sharedThemes.isEmpty, let theme = sharedThemes.first {
            return SynthesisResult(
                prompt: "Deepen your '\(theme)' core.",
                insight: "Both thoughts converge on '\(theme)'. Since '\(ideaA.content.prefix(20))...' and '\(ideaB.content.prefix(20))...' share this root, what is the underlying principle they both serve?",
                confidence: 0.8
            )
        }
        
        // 3. Bridge via Shared Keyword
        if !intersection.isEmpty, let bridge = intersection.first {
            return SynthesisResult(
                prompt: "Bridge via '\(bridge)'.",
                insight: "You mentioned '\(bridge)' in two different contexts. How can the structure of '\(ideaA.content.prefix(15))...' be applied to improve '\(ideaB.content.prefix(15))...'?",
                confidence: 0.7
            )
        }
        
        // 4. Creative Leap (Low Similarity, High Tension)
        return SynthesisResult(
            prompt: "Provoke a Synthesis",
            insight: "These ideas are conceptually distant (\(Int(similarity * 100))% match). If you were forced to combine them, what third perspective is born from the friction between '\(themesA.first ?? "A")' and '\(themesB.first ?? "B")'?",
            confidence: Float(similarity)
        )
    }
}
