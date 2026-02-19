import SwiftUI
import SwiftData

/// A meditative playground for discovering hidden connections.
struct SynthesisPlaygroundView: View {
    let unlinkedSimilarPairs: [(Idea, Idea, Double)]
    let onSynthesize: (Idea, Idea) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionLabel("SYNTHESIS PLAYGROUND")
            
            if unlinkedSimilarPairs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 30))
                        .foregroundStyle(Pastel.primaryText.opacity(0.1))
                    Text("No hidden bridges found yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(Pastel.primaryText.opacity(0.3))
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(RoundedRectangle(cornerRadius: 24).fill(Pastel.primaryText.opacity(0.02)))
                .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(unlinkedSimilarPairs.prefix(5), id: \.0.id) { pair in
                            SynthesisProposalCard(pair: pair) {
                                onSynthesize(pair.0, pair.1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 16)
    }
    
    private func SectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .kerning(4)
                .foregroundStyle(Pastel.header)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct SynthesisProposalCard: View {
    let pair: (Idea, Idea, Double)
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: -8) {
                Circle().fill(Pastel.accent).frame(width: 8, height: 8)
                Circle().fill(Pastel.mint).frame(width: 8, height: 8).offset(x: 4)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                IdeaPreviewSnippet(idea: pair.0)
                
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Pastel.primaryText.opacity(0.2))
                    .frame(maxWidth: .infinity)
                
                IdeaPreviewSnippet(idea: pair.1)
            }
            
            Button(action: action) {
                HStack {
                    Text("Bridge Ideas")
                    Spacer()
                    Image(systemName: "sparkles")
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(Pastel.accent))
                .foregroundStyle(Pastel.current.id == "paper_theme" ? .white : .black)
            }
        }
        .padding(20)
        .frame(width: 260)
        .background {
            RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Pastel.primaryText.opacity(0.05), lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

struct IdeaPreviewSnippet: View {
    let idea: Idea
    var body: some View {
        Text(idea.content)
            .font(.system(size: 11))
            .lineLimit(2)
            .foregroundStyle(Pastel.primaryText.opacity(0.6))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Pastel.primaryText.opacity(0.03)))
    }
}
