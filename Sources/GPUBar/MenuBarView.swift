import AppKit
import SwiftUI

struct MenuBarView: View {
    private static let menuWidth: CGFloat = 440
    private static let switcherWidth: CGFloat = 408

    let monitor: GPUMonitor
    let config: AppConfig
    let onSettings: () -> Void
    let onRefresh: () -> Void
    let onDisconnect: () -> Void
    let onQuit: () -> Void

    @AppStorage("menuSelection") private var storedSelection = ClusterMenuSelection.overview.storageValue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if self.switcherItems.count > 1 {
                ClusterSwitcherRepresentable(
                    items: self.switcherItems,
                    selected: self.selection,
                    width: Self.switcherWidth,
                    showsIcons: self.config.switcherShowsIcons,
                    onSelect: { newSelection in
                        self.storedSelection = newSelection.storageValue
                    })
                    .frame(
                        width: Self.switcherWidth,
                        height: ClusterSwitcherView.preferredHeight(
                            itemCount: self.switcherItems.count,
                            width: Self.switcherWidth,
                            showsIcons: self.config.switcherShowsIcons))
                    .id(self.switcherIdentity)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                Divider()
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    switch self.selection {
                    case .overview:
                        self.overviewContent
                    case let .cluster(clusterID):
                        self.clusterContent(for: clusterID)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 520)

            if let error = self.monitor.error, !error.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            HStack(spacing: 8) {
                FooterButton(title: "Refresh", systemImage: "arrow.clockwise", action: self.onRefresh)
                FooterButton(title: "Settings", systemImage: "slider.horizontal.3", action: self.onSettings)

                Spacer(minLength: 10)

                if !self.config.username.isEmpty {
                    Text(self.config.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                FooterButton(title: "Disconnect", systemImage: "wifi.slash", action: self.onDisconnect)
                FooterButton(title: "Quit", systemImage: "xmark.circle", action: self.onQuit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: Self.menuWidth)
    }

    private var switcherItems: [ClusterSwitcherItem] {
        var items: [ClusterSwitcherItem] = []
        if self.config.showOverviewTab, !self.overviewClusters.isEmpty {
            items.append(
                ClusterSwitcherItem(
                    selection: .overview,
                    title: "Overview",
                    image: self.clusterIcon(for: nil),
                    accentColor: .secondaryLabelColor,
                    availabilityPercent: self.overallFreePercent))
        }

        for cluster in self.visibleClusterTabs {
            items.append(
                ClusterSwitcherItem(
                    selection: .cluster(cluster.id),
                    title: AppConfig.displayName(for: cluster.id),
                    image: self.clusterIcon(for: cluster.id),
                    accentColor: self.clusterAccentColor(cluster.id),
                    availabilityPercent: self.freePercent(for: cluster)))
        }
        return items
    }

    private var selection: ClusterMenuSelection {
        let resolved = ClusterMenuSelection.from(storageValue: self.storedSelection)
        if let resolved, self.switcherItems.contains(where: { $0.selection == resolved }) {
            return resolved
        }
        if self.config.showOverviewTab, !self.overviewClusters.isEmpty {
            return .overview
        }
        if let firstCluster = self.visibleClusterTabs.first {
            return .cluster(firstCluster.id)
        }
        return .overview
    }

    private var switcherIdentity: String {
        let ids = self.switcherItems.map { $0.selection.storageValue }.joined(separator: "|")
        return "\(ids)-\(self.selection.storageValue)-\(self.config.switcherShowsIcons)"
    }

    private var orderedClusters: [ClusterData] {
        let preferred = AppConfig.orderedClusterOptions(available: self.monitor.clusters.map(\.id))
        let orderIndex = Dictionary(uniqueKeysWithValues: preferred.enumerated().map { ($0.element, $0.offset) })
        return self.monitor.clusters.sorted {
            let lhsKey = $0.id.lowercased()
            let rhsKey = $1.id.lowercased()
            let lhsIndex = orderIndex[lhsKey] ?? Int.max
            let rhsIndex = orderIndex[rhsKey] ?? Int.max
            if lhsIndex == rhsIndex {
                return lhsKey < rhsKey
            }
            return lhsIndex < rhsIndex
        }
    }

    private var visibleClusterTabs: [ClusterData] {
        let configured = Set(self.config.visibleClusterTabs.map { $0.lowercased() })
        let matches = self.orderedClusters.filter { configured.contains($0.id.lowercased()) }
        return matches.isEmpty ? self.orderedClusters : matches
    }

    private var overviewClusters: [ClusterData] {
        let configured = Set(self.config.overviewSelectedClusters.map { $0.lowercased() })
        let matches = self.orderedClusters.filter { configured.contains($0.id.lowercased()) }
        if !matches.isEmpty {
            return matches
        }
        if !self.visibleClusterTabs.isEmpty {
            return self.visibleClusterTabs
        }
        return self.orderedClusters
    }

    private var overallFreePercent: Double? {
        guard self.monitor.totalGPUs > 0 else { return nil }
        return (Double(self.monitor.totalFree) / Double(self.monitor.totalGPUs)) * 100
    }

    @ViewBuilder
    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuSummaryCard(
                title: "Overview",
                subtitle: self.subtitleText,
                trailingText: self.config.username,
                tint: .accentColor,
                summary: MenuMetricSummary(
                    title: "Cluster availability",
                    percent: self.overallFreePercent ?? 0,
                    primaryText: "\(self.monitor.totalFree) free of \(self.monitor.totalGPUs)",
                    secondaryText: "\(self.monitor.clusters.count) clusters"),
                details: [
                    self.monitor.pendingJobs.isEmpty ? nil : "\(self.monitor.pendingJobs.count) pending jobs",
                    self.monitor.isLoading ? "Refreshing now" : nil,
                ].compactMap { $0 })

            if !self.overviewClusters.isEmpty {
                Divider().padding(.horizontal, 16)
                ForEach(Array(self.overviewClusters.enumerated()), id: \.element.id) { index, cluster in
                    OverviewClusterCardRowView(cluster: cluster, tint: self.color(for: cluster.id))
                    if index < self.overviewClusters.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
            } else {
                EmptyMenuCard(message: "No clusters available yet")
            }

            if !self.monitor.pendingJobs.isEmpty {
                Divider().padding(.horizontal, 16)
                PendingJobsCard(title: "Pending", jobs: Array(self.monitor.pendingJobs.prefix(8)))
            }
        }
    }

    @ViewBuilder
    private func clusterContent(for clusterID: String) -> some View {
        if let cluster = self.orderedClusters.first(where: { $0.id.caseInsensitiveCompare(clusterID) == .orderedSame }) {
            VStack(alignment: .leading, spacing: 0) {
                MenuSummaryCard(
                    title: AppConfig.displayName(for: cluster.id),
                    subtitle: self.subtitleText,
                    trailingText: cluster.nodes.first?.gpuType ?? "GPU",
                    tint: self.color(for: cluster.id),
                    summary: MenuMetricSummary(
                        title: "Availability",
                        percent: self.freePercent(for: cluster) ?? 0,
                        primaryText: "\(cluster.freeGPUs) free of \(cluster.totalGPUs)",
                        secondaryText: "\(cluster.nodes.count) nodes"),
                    details: [
                        cluster.usersSummaryLine,
                        self.clusterPendingJobs(for: cluster.id).isEmpty ? nil : "\(self.clusterPendingJobs(for: cluster.id).count) pending jobs",
                    ].compactMap { $0 })

                Divider().padding(.horizontal, 16)
                NodeListCard(cluster: cluster)

                let pending = self.clusterPendingJobs(for: cluster.id)
                if !pending.isEmpty {
                    Divider().padding(.horizontal, 16)
                    PendingJobsCard(title: "Pending", jobs: pending)
                }
            }
        } else {
            EmptyMenuCard(message: "No data for \(clusterID) yet")
        }
    }

    private var subtitleText: String {
        if self.monitor.isLoading && self.monitor.lastUpdate == nil {
            return "Refreshing…"
        }
        if let lastUpdate = self.monitor.lastUpdate {
            return "Updated \(lastUpdate.formatted(date: .omitted, time: .shortened))"
        }
        return "Not fetched yet"
    }

    private func clusterPendingJobs(for clusterID: String) -> [GPUStatusResponse.PendingJob] {
        self.monitor.pendingJobs.filter {
            guard let cluster = $0.cluster?.lowercased() else { return false }
            return cluster == clusterID.lowercased()
        }
    }

    private func freePercent(for cluster: ClusterData) -> Double? {
        guard cluster.totalGPUs > 0 else { return nil }
        return (Double(cluster.freeGPUs) / Double(cluster.totalGPUs)) * 100
    }

    private func color(for clusterID: String) -> Color {
        switch clusterID.lowercased() {
        case "vegi":
            return Color(nsColor: .systemGreen)
        case "potato":
            return Color(nsColor: .systemOrange)
        case "soda":
            return Color(nsColor: .systemBlue)
        case "independent":
            return Color(nsColor: .systemPurple)
        default:
            return Color.accentColor
        }
    }

    private func clusterAccentColor(_ clusterID: String) -> NSColor {
        switch clusterID.lowercased() {
        case "vegi":
            return .systemGreen
        case "potato":
            return .systemOrange
        case "soda":
            return .systemBlue
        case "independent":
            return .systemPurple
        default:
            return .controlAccentColor
        }
    }

    private func clusterIcon(for clusterID: String?) -> NSImage {
        let symbolName: String
        switch clusterID?.lowercased() {
        case nil:
            symbolName = "square.grid.2x2"
        case "vegi":
            symbolName = "leaf.fill"
        case "potato":
            symbolName = "shippingbox.fill"
        case "soda":
            symbolName = "drop.fill"
        case "independent":
            symbolName = "sparkles"
        default:
            symbolName = "cpu.fill"
        }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage(size: NSSize(width: 16, height: 16))
    }
}

private struct MenuMetricSummary {
    let title: String
    let percent: Double
    let primaryText: String
    let secondaryText: String?
}

private struct MenuSummaryCard: View {
    let title: String
    let subtitle: String
    let trailingText: String
    let tint: Color
    let summary: MenuMetricSummary
    let details: [String]
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer(minLength: 8)
                if !self.trailingText.isEmpty {
                    Text(self.trailingText)
                        .font(.subheadline)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(self.subtitle)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                Spacer(minLength: 8)
                if !self.details.isEmpty {
                    Text(self.details.first ?? "")
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
            }

            Divider()

            GPUMetricRow(summary: self.summary, tint: self.tint)

            if self.details.count > 1 {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(self.details.dropFirst().enumerated()), id: \.offset) { _, detail in
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}

private struct GPUMetricRow: View {
    let summary: MenuMetricSummary
    let tint: Color
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(self.summary.title)
                .font(.body)
                .fontWeight(.medium)
            UsageProgressBar(
                percent: self.summary.percent,
                tint: self.tint,
                accessibilityLabel: self.summary.title)
            HStack(alignment: .firstTextBaseline) {
                Text(self.summary.primaryText)
                    .font(.footnote)
                Spacer(minLength: 8)
                if let secondaryText = self.summary.secondaryText {
                    Text(secondaryText)
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
            }
        }
    }
}

private struct OverviewClusterCardRowView: View {
    let cluster: ClusterData
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppConfig.displayName(for: self.cluster.id))
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer(minLength: 8)
                Text(self.cluster.nodes.first?.gpuType ?? "GPU")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GPUMetricRow(
                summary: MenuMetricSummary(
                    title: "Availability",
                    percent: self.percentFree,
                    primaryText: "\(self.cluster.freeGPUs) free of \(self.cluster.totalGPUs)",
                    secondaryText: "\(self.cluster.nodes.count) nodes"),
                tint: self.tint)

            if let usersSummaryLine = self.cluster.usersSummaryLine {
                Text(usersSummaryLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var percentFree: Double {
        guard self.cluster.totalGPUs > 0 else { return 0 }
        return (Double(self.cluster.freeGPUs) / Double(self.cluster.totalGPUs)) * 100
    }
}

private struct NodeListCard: View {
    let cluster: ClusterData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nodes")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(self.cluster.nodes) { node in
                    NodeUsageRow(node: node)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct NodeUsageRow: View {
    let node: NodeData

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(self.node.name)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer(minLength: 8)
                Text("\(self.node.gpuFree)/\(self.node.gpuTotal)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            UsageProgressBar(
                percent: self.percentFree,
                tint: self.tint,
                accessibilityLabel: "\(self.node.name) availability")

            HStack(alignment: .top, spacing: 8) {
                Text(self.node.gpuType)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if !self.node.userSummary.isEmpty {
                    Text(self.node.userSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }
        }
    }

    private var percentFree: Double {
        guard self.node.gpuTotal > 0 else { return 0 }
        return (Double(self.node.gpuFree) / Double(self.node.gpuTotal)) * 100
    }

    private var tint: Color {
        if self.percentFree >= 50 {
            return Color(nsColor: .systemGreen)
        }
        if self.percentFree >= 20 {
            return Color(nsColor: .systemOrange)
        }
        return Color(nsColor: .systemRed)
    }
}

private struct PendingJobsCard: View {
    let title: String
    let jobs: [GPUStatusResponse.PendingJob]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(self.title)
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(self.jobs.enumerated()), id: \.offset) { _, job in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(job.user)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer(minLength: 8)
                            if let gpus = job.gpus {
                                Text("gpu:\(gpus)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text([job.cluster, job.partition, job.job_name].compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct EmptyMenuCard: View {
    let message: String

    var body: some View {
        Text(self.message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
    }
}

private struct FooterButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 6) {
                Image(systemName: self.systemImage)
                Text(self.title)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }
}

private extension ClusterData {
    var usersSummaryLine: String? {
        let summaries = self.nodes.flatMap(\.users)
        guard !summaries.isEmpty else { return nil }
        return summaries
            .sorted { lhs, rhs in
                if lhs.gpus == rhs.gpus {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.gpus > rhs.gpus
            }
            .prefix(4)
            .map { "\($0.name) (\($0.gpus))" }
            .joined(separator: "  ")
    }
}

private extension NodeData {
    var userSummary: String {
        self.users
            .sorted { lhs, rhs in
                if lhs.gpus == rhs.gpus {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.gpus > rhs.gpus
            }
            .map { "\($0.name) (\($0.gpus))" }
            .joined(separator: "  ")
    }
}
