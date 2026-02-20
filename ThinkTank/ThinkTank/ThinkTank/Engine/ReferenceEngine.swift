import Foundation
import SwiftData
import NaturalLanguage
import Combine

/// Provides real-time "Proactive References" as the user types.
/// This matches current input against the existing "Mind Tank" to surface buried context.
@MainActor
final class ReferenceEngine: ObservableObject {
    
    @Published var suggestions: [Idea] = []
    
    private var container: ModelContainer?
    private var lastQuery: String = ""
    private var searchTask: Task<Void, Never>?
    
    init(container: ModelContainer? = nil) {
        self.container = container
    }
    
    func setContainer(_ container: ModelContainer) {
        self.container = container
    }
    
    /// Finds similar notes based on the current text fragment.
    func findReferences(for input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't search for very short snippets
        guard text.count > 10 else {
            suggestions = []
            return
        }
        
        // Debounce to avoid overloading the background thread
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            
            guard let container = self.container else { return }
            
            // Generate embedding off-main-thread (CPU heavy)
            let currentEmbedding = await Task.detached(priority: .utility) {
                SemanticProcessor.generateEmbedding(for: text)
            }.value
            
            guard let currentEmbedding else { return }
            if Task.isCancelled { return }
            
            // ModelContext operations stay on MainActor
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Idea>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            // Fetch last 100 for candidate pool
            let candidates = (try? context.fetch(descriptor))?.prefix(100) ?? []
            
            let matches: [(id: UUID, embedding: [Double])] = candidates.compactMap {
                guard let emb = $0.embedding else { return nil }
                return ($0.id, emb)
            }
            
            let results = SimilarityEngine.computeSemanticEdges(
                newEmbedding: currentEmbedding,
                candidates: matches,
                threshold: 0.72
            )
            .sorted { $0.score > $1.score }
            .prefix(3)
            
            let resultIDs = results.map { $0.targetID }
            self.suggestions = Array(candidates.filter { resultIDs.contains($0.id) })
        }
    }
}
