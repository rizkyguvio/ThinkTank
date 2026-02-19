import SwiftUI
import SwiftData

/// Handles importing notes from external sources like the Clipboard (e.g., from Apple Notes).
@MainActor
final class ImportManager {
    static let shared = ImportManager()
    
    /// Parses text from the clipboard and imports it as individual notes.
    /// Splits text by double newlines or bullet points to identify separate thoughts.
    func importFromClipboard(modelContext: ModelContext, processor: RipItProcessor) -> Int {
        guard let content = UIPasteboard.general.string, !content.isEmpty else { return 0 }
        
        // Strategy: Split by common note separators
        // 1. Double newlines (typical paragraph separation)
        // 2. Bullet points at start of lines
        let rawItems = content.components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\n• ") }
            .flatMap { $0.components(separatedBy: "\n- ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var count = 0
        for item in rawItems {
            processor.process(content: item, in: modelContext)
            count += 1
        }
        
        return count
    }
}
