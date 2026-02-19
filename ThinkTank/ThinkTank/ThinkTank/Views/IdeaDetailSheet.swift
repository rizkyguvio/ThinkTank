import SwiftUI
import SwiftData
import WidgetKit

/// Bottom sheet shown when a node is tapped in the idea web.
struct IdeaDetailSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let idea: Idea
    let connectedIdeas: [Idea]

    @State private var newTag: String = ""
    @State private var isAddingTag: Bool = false

    /// Callback when user taps a connected idea to navigate to it.
    var onNavigate: ((UUID) -> Void)?

    var body: some View {
        ZStack {
            Pastel.radialBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header: Status + Date
                    HStack {
                        Menu {
                            ForEach(IdeaStatus.allCases, id: \.self) { status in
                                Button { changeStatus(to: status) } label: { Label(status.label, systemImage: status.icon) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: idea.status.icon).font(.caption)
                                Text(idea.status.label).font(.caption2).fontWeight(.bold)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Pastel.color(for: idea.status).opacity(0.15)))
                            .foregroundStyle(Pastel.color(for: idea.status))
                        }

                        Spacer()

                        Text(idea.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(Pastel.primaryText.opacity(0.3))
                    }

                    // Full content
                    Text(idea.content)
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(Pastel.primaryText)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    // Tags Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("THEME TAGS")
                                .font(.system(size: 10, weight: .bold))
                                .kerning(2)
                                .foregroundStyle(Pastel.primaryText.opacity(0.4))
                            
                            Spacer()
                            
                            Button {
                                withAnimation { isAddingTag.toggle() }
                            } label: {
                                Image(systemName: isAddingTag ? "minus.circle.fill" : "plus.circle.fill")
                                    .foregroundStyle(Pastel.accent)
                                    .font(.system(size: 18))
                            }
                        }
                        
                        if isAddingTag {
                            HStack {
                                TextField("Add new tag...", text: $newTag)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Pastel.primaryText)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Pastel.primaryText.opacity(0.05)))
                                    .onSubmit { addTag() }
                                
                                Button { addTag() } label: {
                                    Text("Add").font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Pastel.accent).foregroundStyle(ThemeManager.shared.currentTheme.id == "neon" || ThemeManager.shared.currentTheme.id == "nordic" || ThemeManager.shared.currentTheme.id == "sunset" ? .black : .white).clipShape(Capsule())
                                }
                                .disabled(newTag.isEmpty)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        FlowLayout(spacing: 8) {
                            ForEach(idea.themeTags, id: \.self) { tag in
                                HStack(spacing: 4) {
                                    Text(tag)
                                    Button { removeTag(tag) } label: {
                                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                    }
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Pastel.accent.opacity(0.12), in: Capsule())
                                .foregroundStyle(Pastel.accent)
                            }
                        }
                    }

                    // Connected ideas
                    if !connectedIdeas.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("COGNITIVE BRIDGES")
                                .font(.system(size: 10, weight: .bold))
                                .kerning(2)
                                .foregroundStyle(Pastel.primaryText.opacity(0.4))
                            
                            VStack(spacing: 12) {
                                ForEach(connectedIdeas) { connected in
                                    Button { onNavigate?(connected.id) } label: {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Pastel.color(for: connected.status))
                                                .frame(width: 8, height: 8)
                                            
                                            Text(connected.content)
                                                .font(.system(size: 14))
                                                .foregroundStyle(Pastel.primaryText.opacity(0.8))
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Pastel.primaryText.opacity(0.2))
                                        }
                                        .padding(16)
                                        .background(RoundedRectangle(cornerRadius: 16).fill(Pastel.primaryText.opacity(0.04)))
                                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Pastel.primaryText.opacity(0.05), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // Action Bar: Subtle management tools
                    HStack(spacing: 12) {
                        // Toggle Status: Resolved/Active
                        let isResolved = idea.status == .resolved
                        Button {
                            changeStatus(to: isResolved ? .active : .resolved)
                        } label: {
                            Label(isResolved ? "Reactivate" : "Resolve", systemImage: isResolved ? "lightbulb.fill" : "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(isResolved ? Pastel.peach.opacity(0.1) : Pastel.sky.opacity(0.1))
                                .foregroundStyle(isResolved ? Pastel.peach : Pastel.sky)
                                .clipShape(Capsule())
                        }

                        // Archive
                        if idea.status != .archived {
                            Button { changeStatus(to: .archived) } label: {
                                Label("Archive", systemImage: "archivebox")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background(Pastel.primaryText.opacity(0.05))
                                    .foregroundStyle(Pastel.primaryText.opacity(0.4))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Spacer()
                        
                        // Delete
                        Button(role: .destructive) { deleteIdea() } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .bold))
                                .padding(10)
                                .background(Pastel.rose.opacity(0.1))
                                .foregroundStyle(Pastel.rose)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func changeStatus(to newStatus: IdeaStatus) {
        withAnimation { idea.status = newStatus }
        HapticManager.shared.softTap()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        
        if !idea.themeTags.contains(tag) {
            withAnimation {
                idea.themeTags.append(tag)
                newTag = ""
                isAddingTag = false
            }
            HapticManager.shared.lightTap()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func removeTag(_ tag: String) {
        withAnimation {
            idea.themeTags.removeAll(where: { $0 == tag })
        }
        HapticManager.shared.softTap()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func deleteIdea() {
        modelContext.delete(idea)
        try? modelContext.save()
        HapticManager.shared.lightTap()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews); return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    private struct LayoutResult { var size: CGSize; var positions: [CGPoint] }
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity; var positions: [CGPoint] = []; var x: CGFloat = 0; var y: CGFloat = 0; var lineHeight: CGFloat = 0; var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += lineHeight + spacing; lineHeight = 0 }
            positions.append(CGPoint(x: x, y: y)); lineHeight = max(lineHeight, size.height); x += size.width + spacing; totalWidth = max(totalWidth, x)
        }
        return LayoutResult(size: CGSize(width: totalWidth, height: y + lineHeight), positions: positions)
    }
}
