import SwiftData
import SwiftUI

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.name) private var holdings: [Holding]
    @Query private var settings: [UserSettings]

    @State private var draftGoal: Double = 0
    @State private var validationMessage: String?

    private var summary: PortfolioSummary {
        PortfolioCalculator.summarize(holdings)
    }

    private var activeSettings: UserSettings? {
        settings.first
    }

    private var goal: Double {
        activeSettings?.netWorthGoal ?? 0
    }

    private var progress: Double {
        goal > 0 ? min(summary.totalNetWorth / goal, 1) : 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                goalHero
                planningCards
            }
            .padding(28)
        }
        .premiumPageBackground()
        .onAppear {
            draftGoal = goal
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Goals")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Track progress toward a target net worth using your local portfolio value.")
                .font(.callout)
                .foregroundStyle(WorthlineTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var goalHero: some View {
        SectionCard {
            HStack(alignment: .center, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Net Worth Goal", subtitle: "Stored in local app settings")
                    Text(summary.totalNetWorth, format: Formatters.currency)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(goal > 0 ? "\(progress.formatted(Formatters.percent)) of \(goal.formatted(Formatters.currency))" : "Set a target to start tracking progress.")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(WorthlineTheme.textSecondary)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                            Capsule()
                                .fill(WorthlineTheme.accent)
                                .frame(width: max(goal > 0 ? 8 : 0, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 12)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Target net worth", value: $draftGoal, format: .number.precision(.fractionLength(0...2)))
                    PrimaryButton(title: "Save Goal", symbol: "checkmark") {
                        saveGoal()
                    }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(WorthlineTheme.negative)
                    }
                }
                .frame(width: 260)
            }
        }
    }

    private var planningCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
            StatCard(title: "Remaining", value: max(goal - summary.totalNetWorth, 0).formatted(Formatters.currency), symbol: "flag.checkered", tint: WorthlineTheme.warning)
            StatCard(title: "Current Gain/Loss", value: summary.unrealizedGainLoss.formatted(Formatters.currency), detail: summary.unrealizedGainLossPercent.formatted(Formatters.percent), symbol: "arrow.up.right.circle", tint: summary.unrealizedGainLoss >= 0 ? WorthlineTheme.positive : WorthlineTheme.negative)
            StatCard(title: "Allocation Groups", value: "\(summary.allocation.count)", symbol: "chart.pie", tint: .teal)
        }
    }

    private func saveGoal() {
        guard draftGoal >= 0 else {
            validationMessage = "Goal cannot be negative."
            return
        }
        let target = activeSettings ?? UserSettings()
        target.netWorthGoal = draftGoal
        if activeSettings == nil {
            modelContext.insert(target)
        }
        try? modelContext.save()
        validationMessage = nil
    }
}

