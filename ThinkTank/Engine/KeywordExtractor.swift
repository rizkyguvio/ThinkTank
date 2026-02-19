import Foundation
import NaturalLanguage

/// Extracts keywords from raw text using Apple's NaturalLanguage framework.
///
/// Pipeline: tokenise → remove stop words → lemmatise → filter by length.
/// Runs entirely on-device, no model download required.
enum KeywordExtractor {

    // MARK: - Public

    /// Extract meaningful keywords from a string.
    /// - Returns: De-duplicated, lowercased, lemmatised tokens (length ≥ 3).
    static func extract(from text: String) -> [String] {
        let tokens = lemmatise(text)
        let filtered = tokens.filter { token in
            token.count >= 3 && !stopWords.contains(token)
        }
        // Preserve order, remove duplicates.
        return Array(NSOrderedSet(array: filtered)) as? [String] ?? filtered
    }

    // MARK: - Private

    /// Use NLTagger to lemmatise every word in the input.
    private static func lemmatise(_ text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text.lowercased()

        var lemmas: [String] = []

        tagger.enumerateTags(
            in: text.lowercased().startIndex..<text.lowercased().endIndex,
            unit: .word,
            scheme: .lemma
        ) { tag, range in
            let word = String(text.lowercased()[range])
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)

            if word.isEmpty { return true }

            // Use the lemma if available, otherwise the raw word.
            let lemma = tag?.rawValue.lowercased() ?? word
            lemmas.append(lemma)
            return true
        }

        return lemmas
    }

    // MARK: - Stop words

    /// Minimal English stop word list (175 common words).
    /// Kept as a static Set for O(1) lookups.
    private static let stopWords: Set<String> = [
        "a", "about", "above", "after", "again", "against", "all", "am", "an",
        "and", "any", "are", "aren't", "as", "at", "be", "because", "been",
        "before", "being", "below", "between", "both", "but", "by", "can",
        "can't", "cannot", "could", "couldn't", "did", "didn't", "do", "does",
        "doesn't", "doing", "don't", "down", "during", "each", "few", "for",
        "from", "further", "get", "got", "had", "hadn't", "has", "hasn't",
        "have", "haven't", "having", "he", "her", "here", "hers", "herself",
        "him", "himself", "his", "how", "i", "if", "in", "into", "is", "isn't",
        "it", "it's", "its", "itself", "just", "let", "like", "ll", "me",
        "might", "more", "most", "must", "mustn't", "my", "myself", "no",
        "nor", "not", "of", "off", "on", "once", "only", "or", "other",
        "ought", "our", "ours", "ourselves", "out", "over", "own", "re",
        "same", "shall", "shan't", "she", "should", "shouldn't", "so", "some",
        "such", "than", "that", "the", "their", "theirs", "them", "themselves",
        "then", "there", "these", "they", "this", "those", "through", "to",
        "too", "under", "until", "up", "ve", "very", "was", "wasn't", "we",
        "were", "weren't", "what", "when", "where", "which", "while", "who",
        "whom", "why", "will", "with", "won't", "would", "wouldn't", "you",
        "your", "yours", "yourself", "yourselves",
    ]
}
