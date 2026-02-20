import SwiftUI
import SwiftData
import WidgetKit
import UniformTypeIdentifiers

/// Displays all captured ideas in an elegant list.
struct NotesView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Idea.createdAt, order: .reverse) private var allIdeas: [Idea]
    @Query private var edges: [GraphEdge]

    @ObservedObject var processor: RipItProcessor
    
    @State private var sortNewestFirst = true
    @State private var filterStatus: IdeaStatus? = .active
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var selectedIdea: Idea?
    @State private var selectedTag: String? = nil
    @State private var showTagPicker = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage: String?
    
    // Unified Importer State
    enum ImporterType: Identifiable {
        case restore, autoBackup
        var id: Int { hashValue }
    }
    @State private var activeImporter: ImporterType?
    
    @State private var backupFile: BackupWrapper?

    private var filteredIdeas: [Idea] {
        var results = allIdeas
        
        // 1. Status Filter
        if let status = filterStatus { results = results.filter { $0.status == status } }
        
        // 2. Tag Filter
        if let tag = selectedTag { results = results.filter { $0.themeTags.contains(tag) } }
        
        // 3. Hybrid Search (Lexical + Semantic)
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            
            // Lexical matches (exact words)
            let lexicalMatches = results.filter { $0.content.lowercased().contains(query) }
            
            // Semantic matches (conceptual)
            // We only trigger semantic search for queries > 3 chars to avoid noise
            var semanticMatches: [Idea] = []
            if query.count > 3, let queryEmbedding = SemanticProcessor.generateEmbedding(for: query) {
                semanticMatches = results.filter { idea in
                    guard let ideaEmbedding = idea.embedding else { return false }
                    let score = SemanticProcessor.cosineSimilarity(queryEmbedding, ideaEmbedding)
                    return score > 0.72 // High relevance threshold
                }
            }
            
            // Combine and Dedup
            let combined = Array(Set(lexicalMatches + semanticMatches))
            
            // Sort by relevance (Lexical matches first, then newest)
            results = combined.sorted { a, b in
                let aLex = a.content.lowercased().contains(query)
                let bLex = b.content.lowercased().contains(query)
                if aLex != bLex { return aLex }
                return a.createdAt > b.createdAt
            }
        } else {
            // Standard Sort
            if !sortNewestFirst { results = results.reversed() }
        }
        
        return results
    }

    private var allUniqueTags: [String] {
        let tags = allIdeas.flatMap { $0.themeTags }
        return Array(Set(tags)).sorted()
    }

    var body: some View {
        ZStack {
            Pastel.radialBackground

            VStack(spacing: 0) {
                // Subtle Section Label (Navigation-Replacement)
                HStack {
                    Text("NOTES")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(4)
                        .foregroundStyle(Pastel.header)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 50)

                // Consolidated Control: Search + Filter
                HStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    
                    filterMenu
                    
                    tagButton
                    
                    settingsButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                activeFilterIndicators

                if allIdeas.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    notesList
                }
            }
        }
        .onChange(of: searchText) { old, new in
            if old.isEmpty && !new.isEmpty {
                HapticManager.shared.selectionTick()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            SystemActionsSheet(
                processor: processor,
                activeImporter: $activeImporter,
                backupFile: $backupFile,
                restoreMessage: $restoreMessage,
                showRestoreAlert: $showRestoreAlert
            )
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: Binding(
                get: { activeImporter != nil },
                set: { if !$0 { /* Handled in result */ } }
            ),
            allowedContentTypes: activeImporter == .restore ? [.json] : [.folder],
            allowsMultipleSelection: activeImporter == .autoBackup
        ) { result in
            handleImporterResult(result)
        }
        .sheet(item: $backupFile) { wrapper in
            ShareActivityView(activityItems: [wrapper.url])
        }
        .alert("Status", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restoreMessage ?? "")
        }
        .sheet(item: $selectedIdea) { idea in
            IdeaDetailSheet(
                idea: idea,
                connectedIdeas: fetchConnected(for: idea)
            ) { targetID in
                if let next = allIdeas.first(where: { $0.id == targetID }) {
                    selectedIdea = next
                }
            }
        }
        .sheet(isPresented: $showTagPicker) {
            TagPickerSheet(tags: allUniqueTags, selectedTag: $selectedTag)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func handleImporterResult(_ result: Result<[URL], Error>) {
        guard let type = activeImporter else { 
            activeImporter = nil
            return 
        }
        activeImporter = nil
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if type == .restore {
                Task {
                    do {
                        let count = try BackupManager.shared.restoreBackup(from: url, modelContext: modelContext)
                        restoreMessage = "Successfully restored \(count) notes."
                    } catch {
                        restoreMessage = "Failed to restore: \(error.localizedDescription)"
                    }
                    showRestoreAlert = true
                }
            } else if type == .autoBackup {
                do {
                    try BackupManager.shared.setAutoBackupFolder(url: url)
                    restoreMessage = "Auto-backup folder set successfully!"
                } catch {
                    restoreMessage = "Failed to set folder: \(error.localizedDescription)"
                }
                showRestoreAlert = true
            }
            
        case .failure(let error):
            restoreMessage = "Error: \(error.localizedDescription)"
            showRestoreAlert = true
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Sort") {
                Button { sortNewestFirst = true } label: { Label("Newest First", systemImage: sortNewestFirst ? "checkmark" : "") }
                Button { sortNewestFirst = false } label: { Label("Oldest First", systemImage: !sortNewestFirst ? "checkmark" : "") }
            }
            Section("Filter") {
                Button { withAnimation { filterStatus = nil } } label: { Label("All Notes", systemImage: filterStatus == nil ? "checkmark" : "") }
                ForEach(IdeaStatus.allCases, id: \.self) { status in
                    Button { withAnimation { filterStatus = status } } label: { Label(status.label, systemImage: filterStatus == status ? "checkmark" : status.icon) }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Pastel.primaryText.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(Pastel.primaryText.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Pastel.primaryText.opacity(0.1), lineWidth: 1))
        }
    }

    private var activeFilterIndicators: some View {
        Group {
            if filterStatus != nil || selectedTag != nil || !searchText.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if !searchText.isEmpty {
                            FilterPill(label: "Search: \(searchText)", color: Pastel.accent) { searchText = "" }
                        }
                        
                        if let status = filterStatus {
                            FilterPill(label: status.label, color: Pastel.color(for: status)) { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { filterStatus = nil } }
                        }
                        
                        if let tag = selectedTag {
                            FilterPill(label: "#\(tag)", color: Pastel.mint) { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedTag = nil } }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var tagButton: some View {
        Button {
            showTagPicker = true
        } label: {
            ZStack {
                Image(systemName: "tag")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(selectedTag != nil ? Pastel.accent : Pastel.primaryText.opacity(0.4))
                
                if selectedTag != nil {
                    Circle()
                        .fill(Pastel.accent)
                        .frame(width: 6, height: 6)
                        .offset(x: 8, y: -8)
                }
            }
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 14).fill(Pastel.primaryText.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selectedTag != nil ? Pastel.accent.opacity(0.3) : Pastel.primaryText.opacity(0.1), lineWidth: 1))
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Pastel.primaryText.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(Pastel.primaryText.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Pastel.primaryText.opacity(0.1), lineWidth: 1))
        }
    }

    private var notesList: some View {
        List {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    let count = filteredIdeas.count
                    let statusLabel = filterStatus?.label ?? "Captured"
                    Text("\(count) \(statusLabel) \(count == 1 ? "Idea" : "Ideas")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Pastel.primaryText.opacity(0.8))
                    
                    if let tag = selectedTag {
                        Text("Filtered by #\(tag)")
                            .font(.system(size: 11))
                            .foregroundStyle(Pastel.mint)
                    } else if !searchText.isEmpty {
                        Text("Searching for \"\(searchText)\"")
                            .font(.system(size: 11))
                            .foregroundStyle(Pastel.accent)
                    } else {
                        Text(filterStatus == nil ? "Your total collection" : "Filtered view")
                            .font(.system(size: 11))
                            .foregroundStyle(Pastel.primaryText.opacity(0.3))
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            ForEach(filteredIdeas) { idea in
                NoteCard(idea: idea) {
                    selectedIdea = idea
                } onStatusChange: { newStatus in
                    changeStatus(idea, to: newStatus)
                } onDelete: {
                    deleteIdea(idea)
                }
                .id(idea.id)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteIdea(idea)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        let newStatus: IdeaStatus = idea.status == .resolved ? .active : .resolved
                        changeStatus(idea, to: newStatus)
                    } label: {
                        Label(
                            idea.status == .resolved ? "Reactivate" : "Resolve",
                            systemImage: idea.status == .resolved ? "lightbulb.fill" : "checkmark.circle.fill"
                        )
                    }
                    .tint(idea.status == .resolved ? .orange : .blue)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 140, for: .scrollContent)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: filteredIdeas.map(\.id))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 64))
                .foregroundStyle(Pastel.accent.opacity(0.2))
            Text("No notes found")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Pastel.primaryText.opacity(0.5))
            Text("Try searching for something else or capture a new idea in the first tab.")
                .font(.system(size: 14))
                .foregroundStyle(Pastel.primaryText.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func changeStatus(_ idea: Idea, to newStatus: IdeaStatus) {
        if newStatus == .archived {
            HapticManager.shared.archivePulse()
        } else {
            HapticManager.shared.softTap()
        }
        
        // Update immediately — no animation wrapper.
        // The swipe action handles its own dismiss animation.
        // The List's .animation() modifier drives the spring reflow
        // when filteredIdeas changes.
        idea.status = newStatus
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func deleteIdea(_ idea: Idea) {
        HapticManager.shared.triggerMediumImpact()
        
        // Phase 1: Delete
        modelContext.delete(idea)
        try? modelContext.save()
        
        // Phase 2: Widget
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func fetchConnected(for idea: Idea) -> [Idea] {
        let activeIDs = Set(allIdeas.map(\.id))
        let targetIDs = edges.filter { $0.sourceIdea?.id == idea.id }.map { $0.targetIdeaID }.filter { activeIDs.contains($0) }
        return allIdeas.filter { targetIDs.contains($0.id) }
    }
}

// MARK: - Search Bar Component

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Pastel.primaryText.opacity(0.3))
            
            TextField("Search notes...", text: $text)
                .font(.system(size: 16))
                .foregroundStyle(Pastel.primaryText)
            
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Pastel.primaryText.opacity(0.3))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Pastel.primaryText.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Pastel.primaryText.opacity(0.1), lineWidth: 1))
        )
    }
}

// MARK: - Note Card (Physical Swipe Fix)

struct NoteCard: View {
    let idea: Idea
    let onTap: () -> Void
    let onStatusChange: (IdeaStatus) -> Void
    let onDelete: () -> Void
    
    @State private var isBadgePressed = false
    @State private var isCardPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(idea.content)
                        .font(.system(size: 17))
                        .foregroundStyle(Pastel.primaryText)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                    
                    Spacer(minLength: 16)
                    statusBadge
                }

                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                        Text(idea.createdAt, style: .relative)
                        
                        if idea.embedding != nil {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundStyle(Pastel.accent)
                                .opacity(0.8)
                        }
                        
                        if idea.hasReminder {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Pastel.sky)
                                .opacity(0.8)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Pastel.primaryText.opacity(0.4))

                    Spacer()
                    tagsView
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Pastel.primaryText.opacity(0.04))
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(statusColor.opacity(0.15), lineWidth: 1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1.0 : 0.8)
                .scaleEffect(phase.isIdentity ? 1.0 : 0.96)
                .offset(y: phase.value * 8)
        }
    }

    private var statusBadge: some View {
        Menu {
            ForEach(IdeaStatus.allCases, id: \.self) { status in
                Button { onStatusChange(status) } label: { Label(status.label, systemImage: status.icon) }
            }
        } label: {
            Image(systemName: idea.status.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(statusColor)
                .padding(10)
                .background(statusColor.opacity(0.12))
                .clipShape(Circle())
                .contentShape(Circle())
                .scaleEffect(isBadgePressed ? 0.85 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isBadgePressed)
        }
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isBadgePressed = pressing
            if pressing { HapticManager.shared.softTap() }
        }, perform: {})
        .buttonStyle(.plain)
    }

    private var tagsView: some View {
        HStack(spacing: 8) {
            ForEach(idea.themeTags.prefix(2), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Pastel.accent.opacity(0.12)).foregroundStyle(Pastel.accent).clipShape(Capsule())
            }
        }
    }

    private var statusColor: Color { Pastel.color(for: idea.status) }
}



// MARK: - System Actions Sheet

struct SystemActionsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var processor: RipItProcessor
    
    @Binding var activeImporter: NotesView.ImporterType?
    @Binding var backupFile: BackupWrapper?
    @Binding var restoreMessage: String?
    @Binding var showRestoreAlert: Bool
    
    var body: some View {
        ZStack {
            Pastel.radialBackground.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Centered Grabber area is handled by presentationDragIndicator
                
                Text("SYSTEM ACTIONS")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(4)
                    .foregroundStyle(Pastel.header.opacity(0.6))
                    .padding(.top, 44)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 12) {
                        Button {
                            processor.reprocessAll()
                            dismiss()
                        } label: {
                            SystemActionRow(title: "Reprocess Library", icon: "sparkles", color: Pastel.mint)
                        }

                        Button {
                            Task {
                                if let url = try? BackupManager.shared.createBackup(modelContext: modelContext) {
                                    backupFile = BackupWrapper(url: url)
                                    dismiss()
                                }
                            }
                        } label: {
                            SystemActionRow(title: "Backup Data", icon: "square.and.arrow.up", color: Pastel.sky)
                        }
                        
                        Button {
                            dismiss()
                            // Small delay to allow sheet to dismiss before presenting importer
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                activeImporter = .restore
                            }
                        } label: {
                            SystemActionRow(title: "Restore Data", icon: "arrow.clockwise.icloud", color: Pastel.rose)
                        }
                        
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                activeImporter = .autoBackup
                            }
                        } label: {
                            SystemActionRow(title: "Set Auto-Backup Folder", icon: "folder.badge.gear", color: Pastel.accent)
                        }

                    }
                    .padding(.horizontal, 20)
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 20)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("APP THEME")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(4)
                            .foregroundStyle(Pastel.header)
                            .padding(.horizontal, 24)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 20) {
                            ForEach(ThemeManager.shared.allThemes, id: \.id) { theme in
                                ThemeOptionView(
                                    theme: theme,
                                    isSelected: ThemeManager.shared.currentTheme.id == theme.id
                                ) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        ThemeManager.shared.currentTheme = theme
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                }
            }
    }
}

struct ThemeOptionView: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(theme.background)
                        .frame(width: 72, height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(isSelected ? theme.accent.opacity(0.8) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                        )
                    
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: theme.accent.opacity(0.5), radius: 4)
                }
                
                Text(theme.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? Pastel.accent : Pastel.primaryText.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
    }
}

struct SystemActionRow: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 32)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Pastel.primaryText.opacity(0.8))
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Pastel.primaryText.opacity(0.2))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Pastel.primaryText.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Pastel.primaryText.opacity(0.1), lineWidth: 1))
    }
}

struct TagPickerSheet: View {
    let tags: [String]
    @Binding var selectedTag: String?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var filteredTags: [String] {
        if searchText.isEmpty { return tags }
        return tags.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Pastel.radialBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("FILTER BY TAG")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(4)
                    .foregroundStyle(Pastel.header.opacity(0.6))
                    .padding(.top, 28)
                
                SearchBar(text: $searchText)
                    .padding(.horizontal, 20)
                
                ScrollView {
                    if filteredTags.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tag.slash").font(.system(size: 32)).foregroundStyle(Pastel.primaryText.opacity(0.1))
                            Text("No tags found").font(.system(size: 14)).foregroundStyle(Pastel.primaryText.opacity(0.3))
                        }
                        .padding(.top, 60)
                    } else {
                        FlowLayout(spacing: 10) {
                            ForEach(filteredTags, id: \.self) { tag in
                                Button {
                                    withAnimation { selectedTag = tag }
                                    dismiss()
                                } label: {
                                    Text(tag)
                                        .font(.system(size: 13, weight: .bold))
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(selectedTag == tag ? Pastel.accent : Pastel.primaryText.opacity(0.05))
                                        .foregroundStyle(selectedTag == tag ? .white : Pastel.primaryText.opacity(0.6))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(Pastel.primaryText.opacity(selectedTag == tag ? 0 : 0.1), lineWidth: 1))
                                }
                            }
                        }
                        .padding(20)
                    }
                }
                
                Spacer()
            }
        }
    }
}

struct FilterPill: View {
    let label: String
    let color: Color
    let onClear: () -> Void
    
    var body: some View {
        Button {
            onClear()
            HapticManager.shared.snapOff()
        } label: {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 11, weight: .bold))
                Image(systemName: "xmark.circle.fill").font(.system(size: 12))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
        }
    }
}

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct BackupWrapper: Identifiable {
    let id = UUID()
    let url: URL
}
