import Foundation
import SwiftData

/// Handles the export and import of Think Tank data for backup purposes.
/// This ensures user data continuity even if the app container is reset during development.
@MainActor
final class BackupManager {
    static let shared = BackupManager()
    
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    private let bookmarkKey = "ThinkTank_AutoBackupFolder_Bookmark"
    
    // MARK: - Core Logic
    
    private func generateJSON(modelContext: ModelContext) throws -> Data {
        let descriptor = FetchDescriptor<Idea>()
        let allIdeas = try modelContext.fetch(descriptor)
        
        let backupData = allIdeas.map { idea in
            IdeaBackupDTO(
                id: idea.id,
                content: idea.content,
                createdAt: idea.createdAt,
                extractedKeywords: idea.extractedKeywords,
                themeTags: idea.themeTags,
                statusRaw: idea.statusRaw
            )
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backupData)
    }
    
    // MARK: - Manual Export
    
    /// Exports all data to a temporary file for manual sharing.
    func createBackup(modelContext: ModelContext) throws -> URL {
        let jsonData = try generateJSON(modelContext: modelContext)
        let fileName = "ThinkTank_Backup_\(timestampFormatter.string(from: Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try jsonData.write(to: tempURL)
        print("Manual backup created at: \(tempURL.path)")
        return tempURL
    }
    
    // MARK: - Auto-Backup Configuration
    
    /// Saves access to a user-selected folder for automatic backups.
    func setAutoBackupFolder(url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else { throw BackupError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        print("Auto-backup folder configured: \(url.path)")
    }
    
    /// Resolves the saved folder URL if it exists.
    func getAutoBackupFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                print("Bookmark is stale, needs renewal.")
                // In a robust app, we'd ask user to re-pick. For now, try to use it.
            }
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            return nil
        }
    }
    
    // MARK: - Automatic Execution
    
    /// Performs an auto-backup to the configured folder (or local sandbox fallback).
    func performAutoBackup(modelContext: ModelContext) async {
        do {
            let jsonData = try generateJSON(modelContext: modelContext)
            let fileName = "ThinkTank_AutoBackup_\(timestampFormatter.string(from: Date())).json"
            
            if let folderURL = getAutoBackupFolder() {
                // 1. Write to User-Chosen External Folder
                if folderURL.startAccessingSecurityScopedResource() {
                    defer { folderURL.stopAccessingSecurityScopedResource() }
                    let fileURL = folderURL.appendingPathComponent(fileName)
                    try jsonData.write(to: fileURL)
                    print("✅ Auto-backup saved to external folder: \(fileURL.lastPathComponent)")
                    
                    // Cleanup old backups (keep last 5)
                    try? cleanupOldBackups(in: folderURL, prefix: "ThinkTank_AutoBackup_")
                    return
                } else {
                    print("⚠️ Failed to access security scoped folder. Falling back to local.")
                }
            }
            
            // 2. Fallback: Sandbox Documents
            let fallbackURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            try jsonData.write(to: fallbackURL)
            print("⚠️ Auto-backup saved to local sandbox (Folder not set): \(fallbackURL.path)")
            
        } catch {
            print("❌ Auto-backup failed: \(error.localizedDescription)")
        }
    }
    
    private func cleanupOldBackups(in folder: URL, prefix: String) throws {
        let fileManager = FileManager.default
        let fileURLs = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
        
        let backupFiles = fileURLs.filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { (url1, url2) -> Bool in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2 // Newest first
            }
        
        // Keep top 5, delete the rest
        if backupFiles.count > 5 {
            for url in backupFiles.suffix(from: 5) {
                try? fileManager.removeItem(at: url)
                print("Cleaned up old backup: \(url.lastPathComponent)")
            }
        }
    }
    
    // MARK: - Import
    
    func restoreBackup(from url: URL, modelContext: ModelContext) throws -> Int {
        // Accessing the file directly (from import picker)
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backupItems = try decoder.decode([IdeaBackupDTO].self, from: data)
        var restoredCount = 0
        
        // Fetch existing IDs to avoid duplicates
        let existingDescriptor = FetchDescriptor<Idea>()
        let existingIdeas = try modelContext.fetch(existingDescriptor)
        let existingIDs = Set(existingIdeas.map { $0.id })
        
        for item in backupItems {
            if !existingIDs.contains(item.id) {
                let idea = Idea(content: item.content)
                idea.id = item.id
                idea.createdAt = item.createdAt
                idea.extractedKeywords = item.extractedKeywords
                idea.themeTags = item.themeTags
                idea.statusRaw = item.statusRaw
                
                modelContext.insert(idea)
                restoredCount += 1
            }
        }
        
        try modelContext.save()
        return restoredCount
    }
}

// MARK: - Data Transfer Object

struct IdeaBackupDTO: Codable {
    let id: UUID
    let content: String
    let createdAt: Date
    let extractedKeywords: [String]
    let themeTags: [String]
    let statusRaw: String
}

enum BackupError: Error {
    case accessDenied
}
