import SwiftUI

struct MenuBarView: View {
    let monitor: GPUMonitor
    let username: String
    let selectedTab: DashboardTab
    let visibleTabs: [DashboardTab]
    let overviewSections: [OverviewSection]
    let onSelectTab: (DashboardTab) -> Void
    let onSettings: () -> Void
    let onRefresh: () -> Void
    let onDisconnect: () -> Void
    let onQuit: () -> Void

    private var visibleClusterTabs: [DashboardTab] {
        visibleTabs.filter { $0 != .overview }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabSwitcher

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if selectedTab == .overview {
                        overviewContent
                    } else {
                        clusterContent(for: selectedTab)
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 430)

            if let error = monitor.error {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }

            Divider()
            footer
        }
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedTab.title)
                        .font(.headline)
                    Text(selectedTab == .overview ? "Cluster availability at a glance" : "Focused view for \(selectedTab.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        if monitor.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("\(monitor.totalFree) free")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(.primary)

                    if let lastUpdate = monitor.lastUpdate {
                        Text(lastUpdate, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                MetricPill(value: "\(monitor.totalGPUs)", label: "total")
                MetricPill(value: "\(monitor.clusters.count)", label: "clusters")
                MetricPill(value: "\(monitor.pendingJobs.count)", label: "pending")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selectedTab.tint.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(selectedTab.tint.opacity(0.18), lineWidth: 1)
                )
                .padding(10)
        )
    }

    private var tabSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleTabs) { tab in
                    Button(action: { onSelectTab(tab) }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.symbol)
                                .font(.caption)
                            Text(tab.title)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedTab == tab ? tab.tint : Color.primary.opacity(0.07))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        if overviewSections.contains(.summary) {
            summaryCards
        }

        if overviewSections.contains(.clusters) {
            sectionCard(title: "Cluster snapshots", subtitle: "Quick read across your tracked tabs") {
                let snapshotTabs = visibleClusterTabs.isEmpty ? DashboardTab.allCases.filter { $0 != .overview } : visibleClusterTabs
                let snapshotClusters = snapshotTabs.flatMap { clusters(for: $0) }

                if snapshotClusters.isEmpty {
                    EmptyStateView(message: "No tracked clusters are reporting yet.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(snapshotTabs, id: \.self) { tab in
                            let matching = clusters(for: tab)
                            if let cluster = matching.first {
                                OverviewClusterCard(tab: tab, cluster: cluster)
                            }
                        }
                    }
                }
            }
        }

        if overviewSections.contains(.pending) {
            pendingJobsCard
        }

        if overviewSections.contains(.topUsers) {
            topUsersCard
        }
    }

    private func clusterContent(for tab: DashboardTab) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let filteredClusters = clusters(for: tab)

            sectionCard(title: tab.title, subtitle: "Live node status") {
                if filteredClusters.isEmpty {
                    EmptyStateView(message: "No \(tab.title) nodes were returned by the API.")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredClusters) { cluster in
                            ClusterSection(cluster: cluster, tint: tab.tint)
                        }
                    }
                }
            }

            if !monitor.pendingJobs.isEmpty {
                sectionCard(title: "Pending jobs", subtitle: "Shared queue preview") {
                    PendingJobsList(jobs: monitor.pendingJobs)
                }
            }
        }
    }

    private var summaryCards: some View {
        sectionCard(title: "Overview", subtitle: "Fast health check") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    SummaryCard(title: "Free", value: "\(monitor.totalFree)", detail: "ready now", tint: .green)
                    SummaryCard(title: "Used", value: "\(monitor.totalGPUs - monitor.totalFree)", detail: "currently busy", tint: .orange)
                }
                HStack(spacing: 8) {
                    SummaryCard(title: "Clusters", value: "\(monitor.clusters.count)", detail: "reporting", tint: .blue)
                    SummaryCard(title: "Pending", value: "\(monitor.pendingJobs.count)", detail: "queued jobs", tint: .purple)
                }
            }
        }
    }

    private var pendingJobsCard: some View {
        sectionCard(title: "Pending jobs", subtitle: "Next up in the queue") {
            if monitor.pendingJobs.isEmpty {
                EmptyStateView(message: "No pending jobs right now.")
            } else {
                PendingJobsList(jobs: monitor.pendingJobs)
            }
        }
    }

    private var topUsersCard: some View {
        sectionCard(title: "Top users", subtitle: "Current GPU allocation leaders") {
            if monitor.topUsers.isEmpty {
                EmptyStateView(message: "No active users are reported yet.")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(monitor.topUsers.prefix(5).enumerated()), id: \.offset) { _, user in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                Text(user.clusters
                                    .sorted { $0.key < $1.key }
                                    .map { "\($0.key): \($0.value)" }
                                    .joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(user.total)")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .monospacedDigit()
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(action: onRefresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)

            Spacer()

            if !username.isEmpty {
                Text(username)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onSettings) {
                Label("Settings", systemImage: "gear")
            }
            .buttonStyle(.plain)

            Button(action: onDisconnect) {
                Label("Disconnect", systemImage: "wifi.slash")
            }
            .buttonStyle(.plain)

            Button(action: onQuit) {
                Label("Quit", systemImage: "xmark.circle")
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func clusters(for tab: DashboardTab) -> [ClusterData] {
        guard tab != .overview else { return monitor.clusters }
        return monitor.clusters.filter { tab.matches(clusterID: $0.id) }
    }
}

struct ClusterSection: View {
    let cluster: ClusterData
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cluster.name)
                        .font(.system(.caption, design: .monospaced).bold())
                    Text("\(cluster.freeGPUs) free of \(cluster.totalGPUs)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(freeSummary)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12), in: Capsule())
                    .foregroundStyle(tint)
            }

            GPUBar(used: cluster.usedGPUs, total: cluster.totalGPUs, tint: tint)
                .frame(height: 10)

            VStack(spacing: 6) {
                ForEach(cluster.nodes) { node in
                    NodeRow(node: node, tint: tint)
                }
            }
        }
        .padding(12)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var freeSummary: String {
        "\(cluster.freeGPUs)/\(cluster.totalGPUs)"
    }
}

struct NodeRow: View {
    let node: NodeData
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(node.name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(node.gpuType)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(node.gpuFree)/\(node.gpuTotal)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GPUBar(used: node.gpuUsed, total: node.gpuTotal, tint: tint)
                .frame(height: 7)

            if !node.users.isEmpty {
                Text(node.users.map { "\($0.name)(\($0.gpus))" }.joined(separator: " · "))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GPUBar: View {
    let used: Int
    let total: Int
    var tint: Color = .green

    var body: some View {
        GeometryReader { geo in
            let fraction = total > 0 ? CGFloat(used) / CGFloat(total) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 5)
                    .fill(barColor(fraction))
                    .frame(width: geo.size.width * fraction)
            }
        }
    }

    func barColor(_ fraction: CGFloat) -> Color {
        if fraction >= 0.9 { return .red }
        if fraction >= 0.7 { return .orange }
        return tint
    }
}

struct MetricPill: View {
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct OverviewClusterCard: View {
    let tab: DashboardTab
    let cluster: ClusterData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tab.tint)
                .frame(width: 28, height: 28)
                .background(tab.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(cluster.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(cluster.freeGPUs) free")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text("\(cluster.totalGPUs) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PendingJobsList: View {
    let jobs: [GPUStatusResponse.PendingJob]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(jobs.prefix(8).enumerated()), id: \.offset) { _, job in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(job.user)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                        Text(job.job_name ?? job.partition ?? "Waiting for allocation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        if let cluster = job.cluster {
                            Text(cluster)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let gpus = job.gpus {
                            Text("gpu:\(gpus)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

struct EmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
