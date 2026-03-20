import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Previous free GPU count per cluster (for detecting transitions from 0 → N)
    private var previousFreeByCluster: [String: Int] = [:]
    /// Last notification time per cluster (rate limiting)
    private var lastNotificationTime: [String: Date] = [:]
    /// Rate limit: 5 minutes between notifications per cluster
    private let rateLimitInterval: TimeInterval = 300

    private var didSetupDelegate = false

    private override init() {
        super.init()
    }

    private func ensureDelegate() {
        guard !didSetupDelegate else { return }
        didSetupDelegate = true
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        ensureDelegate()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Check clusters for newly available GPUs and send notifications
    func checkAndNotify(clusters: [ClusterData], config: AppConfig) {
        guard config.notifyOnFreeGPU else { return }

        let filter = config.notifyClusterFilter.lowercased()
        let threshold = config.notifyThreshold

        for cluster in clusters {
            // Apply cluster filter
            if !filter.isEmpty && !cluster.id.lowercased().contains(filter) {
                continue
            }

            let previousFree = previousFreeByCluster[cluster.id] ?? 0
            let currentFree = cluster.freeGPUs

            // Update state
            previousFreeByCluster[cluster.id] = currentFree

            // Detect transition: was below threshold, now at or above threshold
            if previousFree < threshold && currentFree >= threshold {
                sendNotification(cluster: cluster, freeCount: currentFree)
            }
        }
    }

    private func sendNotification(cluster: ClusterData, freeCount: Int) {
        // Rate limit check
        if let lastTime = lastNotificationTime[cluster.id],
           Date().timeIntervalSince(lastTime) < rateLimitInterval {
            return
        }
        lastNotificationTime[cluster.id] = Date()

        // Determine GPU type from first node
        let gpuType = cluster.nodes.first?.gpuType ?? "GPU"

        ensureDelegate()

        let content = UNMutableNotificationContent()
        content.title = "GPUs Available"
        content.body = "\(cluster.name): \(freeCount)x \(gpuType) free"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "gpu-free-\(cluster.id)-\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
