import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable, Codable, Hashable {
    case overview
    case vegi
    case potato
    case soda
    case independent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .vegi: return "vegi"
        case .potato: return "potato"
        case .soda: return "soda"
        case .independent: return "independent"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .vegi: return "leaf"
        case .potato: return "circle.grid.2x2"
        case .soda: return "sparkles"
        case .independent: return "person.2"
        }
    }

    var tint: Color {
        switch self {
        case .overview: return .blue
        case .vegi: return .green
        case .potato: return .orange
        case .soda: return .purple
        case .independent: return .pink
        }
    }

    func matches(clusterID: String) -> Bool {
        clusterID.localizedCaseInsensitiveContains(rawValue)
    }
}

enum OverviewSection: String, CaseIterable, Identifiable, Codable, Hashable {
    case summary
    case clusters
    case pending
    case topUsers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "Summary cards"
        case .clusters: return "Cluster snapshots"
        case .pending: return "Pending jobs"
        case .topUsers: return "Top users"
        }
    }

    var subtitle: String {
        switch self {
        case .summary: return "Headline totals and refresh health."
        case .clusters: return "Quick cards for your tracked clusters."
        case .pending: return "Queue preview from the scheduler."
        case .topUsers: return "Current GPU usage leaders."
        }
    }
}

extension Array where Element == DashboardTab {
    static var defaultVisibleTabs: [DashboardTab] {
        DashboardTab.allCases
    }

    func normalizedVisibleTabs() -> [DashboardTab] {
        let chosen = DashboardTab.allCases.filter { contains($0) }
        return chosen.isEmpty ? [.overview] : chosen
    }
}

extension Array where Element == OverviewSection {
    static var defaultOverviewSections: [OverviewSection] {
        OverviewSection.allCases
    }

    func normalizedOverviewSections() -> [OverviewSection] {
        let chosen = OverviewSection.allCases.filter { contains($0) }
        return chosen.isEmpty ? [.summary] : chosen
    }
}
