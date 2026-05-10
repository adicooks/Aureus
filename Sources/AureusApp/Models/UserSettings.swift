import Foundation
import SwiftData

enum RefreshInterval: String, CaseIterable, Codable, Identifiable {
    case manual
    case fiveMinutes
    case fifteenMinutes
    case hourly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: "Manual"
        case .fiveMinutes: "Every 5 Minutes"
        case .fifteenMinutes: "Every 15 Minutes"
        case .hourly: "Hourly"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .manual: nil
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        case .hourly: 3_600
        }
    }
}

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var refreshIntervalRaw: String
    var netWorthGoal: Double
    var requireLocalLock: Bool
    var showSampleDataHint: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        refreshInterval: RefreshInterval = .manual,
        netWorthGoal: Double = 0,
        requireLocalLock: Bool = false,
        showSampleDataHint: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.refreshIntervalRaw = refreshInterval.rawValue
        self.netWorthGoal = netWorthGoal
        self.requireLocalLock = requireLocalLock
        self.showSampleDataHint = showSampleDataHint
        self.createdAt = createdAt
    }

    var refreshInterval: RefreshInterval {
        get { RefreshInterval(rawValue: refreshIntervalRaw) ?? .manual }
        set { refreshIntervalRaw = newValue.rawValue }
    }
}
