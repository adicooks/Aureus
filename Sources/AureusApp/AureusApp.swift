import SwiftData
import SwiftUI

@main
struct AureusApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Holding.self,
            PriceSnapshot.self,
            NetWorthSnapshot.self,
            Transaction.self,
            UserSettings.self,
            WatchlistItem.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Aureus local data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(sharedModelContainer)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Asset") {
                    NotificationCenter.default.post(name: .aureusAddAsset, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Refresh Prices") {
                    NotificationCenter.default.post(name: .aureusRefreshPrices, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let aureusAddAsset = Notification.Name("aureus.addAsset")
    static let aureusRefreshPrices = Notification.Name("aureus.refreshPrices")
}
