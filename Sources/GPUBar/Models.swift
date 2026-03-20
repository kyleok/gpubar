import Foundation

// MARK: - API Response Models

struct GPUStatusResponse: Codable {
    let summary: Summary
    let users: [UserUsage]
    let nodes: [Node]
    let pending: [PendingJob]

    struct Summary: Codable {
        let total: Int
        let used: Int
        var free: Int { total - used }
    }

    struct UserUsage: Codable {
        let name: String
        let total: Int
        let clusters: [String: Int]
    }

    struct Node: Codable {
        let name: String
        let cluster: String
        let partition: String?
        let gpu_type: String?
        let gpu_total: Int
        let gpu_used: Int
        let gpu_free: Int
        let status: String
        let users: [NodeUser]?

        enum CodingKeys: String, CodingKey {
            case name, cluster, partition, gpu_type, gpu_total, gpu_used, gpu_free, status, users
        }
    }

    struct NodeUser: Codable {
        let user: String
        let gpus: Int
    }

    struct PendingJob: Codable {
        let user: String
        let cluster: String?
        let partition: String?
        let gpus: Int?
        let job_name: String?
        let position: Int?
    }
}

// MARK: - App Models

struct ClusterData: Identifiable {
    let id: String  // cluster name
    let name: String
    let nodes: [NodeData]
    var totalGPUs: Int { nodes.reduce(0) { $0 + $1.gpuTotal } }
    var usedGPUs: Int { nodes.reduce(0) { $0 + $1.gpuUsed } }
    var freeGPUs: Int { totalGPUs - usedGPUs }
}

struct NodeData: Identifiable {
    let id: String  // node name
    let name: String
    let cluster: String
    let gpuType: String
    let gpuTotal: Int
    let gpuUsed: Int
    let gpuFree: Int
    let status: String
    let users: [(name: String, gpus: Int)]
}
