import SwiftUI

struct MenuBarView: View {
    let monitor: GPUMonitor
    let username: String
    let onSettings: () -> Void
    let onRefresh: () -> Void
    let onDisconnect: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("GPU Status")
                    .font(.headline)
                Spacer()
                if let lastUpdate = monitor.lastUpdate {
                    Text(lastUpdate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Summary bar
            HStack(spacing: 12) {
                Label("\(monitor.totalFree) free", systemImage: "cpu")
                    .foregroundStyle(.green)
                Text("/")
                    .foregroundStyle(.secondary)
                Text("\(monitor.totalGPUs) total")
                    .foregroundStyle(.secondary)
                Spacer()
                if monitor.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Clusters
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(monitor.clusters) { cluster in
                        ClusterSection(cluster: cluster)
                    }

                    // Pending jobs
                    if !monitor.pendingJobs.isEmpty {
                        Divider().padding(.vertical, 4)
                        Text("PENDING (\(monitor.pendingJobs.count))")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)

                        ForEach(Array(monitor.pendingJobs.prefix(8).enumerated()), id: \.offset) { _, job in
                            HStack(spacing: 6) {
                                Text(job.user)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(width: 80, alignment: .leading)
                                if let cluster = job.cluster {
                                    Text(cluster)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let gpus = job.gpus {
                                    Text("gpu:\(gpus)")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 1)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 400)

            if let error = monitor.error {
                Divider()
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }

            Divider()

            // Actions
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
        .frame(width: 380)
    }
}

struct ClusterSection: View {
    let cluster: ClusterData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Cluster header
            HStack {
                Text(cluster.name)
                    .font(.system(.caption, design: .monospaced).bold())
                    .frame(width: 80, alignment: .leading)

                GPUBar(used: cluster.usedGPUs, total: cluster.totalGPUs)
                    .frame(height: 8)

                Text("\(cluster.freeGPUs)/\(cluster.totalGPUs)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            // Nodes
            ForEach(cluster.nodes) { node in
                NodeRow(node: node)
            }
        }
    }
}

struct NodeRow: View {
    let node: NodeData

    var body: some View {
        HStack(spacing: 4) {
            Text(node.name)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
                .lineLimit(1)

            GPUBar(used: node.gpuUsed, total: node.gpuTotal)
                .frame(width: 50, height: 6)

            Text("\(node.gpuFree)/\(node.gpuTotal)")
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 35, alignment: .trailing)

            Text(node.gpuType)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            // Users
            Text(node.users.map { "\($0.name)(\($0.gpus))" }.joined(separator: " "))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.leading, 12)
        .padding(.vertical, 1)
    }
}

struct GPUBar: View {
    let used: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            let fraction = total > 0 ? CGFloat(used) / CGFloat(total) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green.opacity(0.3))
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(fraction))
                    .frame(width: geo.size.width * fraction)
            }
        }
    }

    func barColor(_ fraction: CGFloat) -> Color {
        if fraction >= 0.9 { return .red }
        if fraction >= 0.7 { return .orange }
        return .green
    }
}
