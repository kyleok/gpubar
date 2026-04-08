import Foundation
import SwiftUI

@Observable
final class GPUMonitor {
    var clusters: [ClusterData] = []
    var pendingJobs: [GPUStatusResponse.PendingJob] = []
    var topUsers: [GPUStatusResponse.UserUsage] = []
    var totalFree: Int = 0
    var totalGPUs: Int = 0
    var lastUpdate: Date?
    var error: String?
    var isLoading = false
    var keyInvalid = false

    private var timer: Timer?
    private let config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    func startPolling() {
        Task { @MainActor in
            await fetch()
        }
        timer?.invalidate()
        let t = Timer(timeInterval: config.refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetch()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func updateInterval(_ interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetch()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @MainActor
    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        var components = URLComponents(string: "\(config.apiURL)/api/gpu/status")
        components?.queryItems = [URLQueryItem(name: "key", value: config.apiKey)]
        guard let url = components?.url else {
            error = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                return
            }

            if httpResponse.statusCode == 403 {
                keyInvalid = true
                error = "Invalid API key — please re-pair from your dashboard"
                return
            }

            guard httpResponse.statusCode == 200 else {
                error = "HTTP \(httpResponse.statusCode)"
                return
            }

            let decoded = try JSONDecoder().decode(GPUStatusResponse.self, from: data)

            // Group nodes by cluster
            var clusterMap: [String: [NodeData]] = [:]
            for node in decoded.nodes {
                let nodeData = NodeData(
                    id: node.name,
                    name: node.name,
                    cluster: node.cluster,
                    gpuType: node.gpu_type ?? node.partition ?? "GPU",
                    gpuTotal: node.gpu_total,
                    gpuUsed: node.gpu_used,
                    gpuFree: node.gpu_free,
                    status: node.status,
                    users: (node.users ?? []).map { ($0.user, $0.gpus) }
                )
                clusterMap[node.cluster, default: []].append(nodeData)
            }

            let clusterOrder = AppConfig.orderedClusterOptions(available: Array(clusterMap.keys))
            let clusterOrderIndex = Dictionary(uniqueKeysWithValues: clusterOrder.enumerated().map { ($0.element, $0.offset) })

            clusters = clusterMap.map { name, nodes in
                ClusterData(
                    id: name,
                    name: name,
                    nodes: nodes.sorted { $0.name < $1.name }
                )
            }.sorted {
                let lhsIndex = clusterOrderIndex[$0.id.lowercased()] ?? Int.max
                let rhsIndex = clusterOrderIndex[$1.id.lowercased()] ?? Int.max
                if lhsIndex == rhsIndex {
                    return $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending
                }
                return lhsIndex < rhsIndex
            }

            pendingJobs = decoded.pending
            topUsers = decoded.users
            totalFree = decoded.summary.free
            totalGPUs = decoded.summary.total
            lastUpdate = Date()
            error = nil
            keyInvalid = false

            NotificationManager.shared.checkAndNotify(clusters: clusters, config: config)

        } catch {
            self.error = error.localizedDescription
        }
    }
}
