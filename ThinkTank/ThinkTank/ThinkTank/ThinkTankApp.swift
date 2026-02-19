import SwiftUI
import SwiftData

@main
struct ThinkTankApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var initError: String?

    @Environment(\.scenePhase) private var scenePhase

    // CRITICAL: Replace with your actual App Group ID from Xcode Capabilities
    static let appGroup = "group.personal.ThinkTank.Gio"

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = modelContainer {
                    MainRootView()
                        .modelContainer(container)
                } else if let error = initError {
                    fatalErrorView(error)
                } else {
                    ZStack {
                        Pastel.radialBackground.ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView().tint(Pastel.accent)
                            Text("Warming up the Think Tank...")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .onAppear { initializeContainer() }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background, let container = modelContainer {
                Task {
                    await BackupManager.shared.performAutoBackup(modelContext: container.mainContext)
                }
            }
        }
    }

    private func initializeContainer() {
        let schema = Schema([Idea.self, Theme.self, GraphEdge.self])
        
        // Configure shared storage for App Group (shares data with Widgets)
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
        let storeURL = groupURL?.appendingPathComponent("ThinkTank.sqlite")
        
        let config = ModelConfiguration(url: storeURL ?? URL.documentsDirectory.appending(path: "ThinkTank.sqlite"))
        
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
            print("✅ SwiftData initialized in App Group: \(Self.appGroup)")
        } catch {
            print("❌ Failed to initialize shared container: \(error.localizedDescription)")
            // Fallback to local
            do {
                self.modelContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration()])
            } catch {
                self.initError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func fatalErrorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 50)).foregroundStyle(Pastel.rose)
            Text("Initialization Failed").font(.system(size: 20, weight: .bold))
            Text(error).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
            Button("Retry") { self.initError = nil; initializeContainer() }.buttonStyle(.borderedProminent).tint(Pastel.rose)
        }
    }
}
