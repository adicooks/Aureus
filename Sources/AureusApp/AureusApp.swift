import SwiftData
import SwiftUI

private enum AppLaunchRouter {
    static func routeRawExecutableToAppBundleIfNeeded() {
        guard !isRunningFromAppBundle else { return }
        guard let scriptURL = findBuildAppScript() else { return }

        let process = Process()
        process.executableURL = scriptURL
        process.arguments = ["--open"]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            fputs("Unable to launch Aureus.app: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        exit(process.terminationStatus)
    }

    private static var isRunningFromAppBundle: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    private static func findBuildAppScript() -> URL? {
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            currentDirectory.appendingPathComponent("Scripts/build-app.sh"),
            currentDirectory.deletingLastPathComponent().appendingPathComponent("Scripts/build-app.sh"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Scripts/build-app.sh")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = AppIconRenderer.makeIcon()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct AureusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        AppLaunchRouter.routeRawExecutableToAppBundleIfNeeded()
    }

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
