import Foundation

struct AppConfig {
    var apiURL: String
    var coreURL: String
    var apiKey: String
    var username: String
    var refreshInterval: TimeInterval
    var launchAtLogin: Bool
    var notifyOnFreeGPU: Bool
    var notifyThreshold: Int  // Notify when N+ GPUs are free
    var notifyClusterFilter: String  // Empty = all clusters

    static let defaultURL = "https://status.example.com"
    static let defaultCoreURL = "https://core.example.com"
    static let defaultInterval: TimeInterval = 60

    var isPaired: Bool { !apiKey.isEmpty && apiURL != Self.defaultURL }

    init() {
        apiURL = UserDefaults.standard.string(forKey: "apiURL") ?? Self.defaultURL
        coreURL = UserDefaults.standard.string(forKey: "coreURL") ?? Self.defaultCoreURL
        apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval").nonZero ?? Self.defaultInterval
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        notifyOnFreeGPU = UserDefaults.standard.bool(forKey: "notifyOnFreeGPU")
        notifyThreshold = UserDefaults.standard.integer(forKey: "notifyThreshold").nonZero ?? 1
        notifyClusterFilter = UserDefaults.standard.string(forKey: "notifyClusterFilter") ?? ""
    }

    func save() {
        UserDefaults.standard.set(apiURL, forKey: "apiURL")
        UserDefaults.standard.set(coreURL, forKey: "coreURL")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        UserDefaults.standard.set(notifyOnFreeGPU, forKey: "notifyOnFreeGPU")
        UserDefaults.standard.set(notifyThreshold, forKey: "notifyThreshold")
        UserDefaults.standard.set(notifyClusterFilter, forKey: "notifyClusterFilter")
    }

    mutating func disconnect() {
        apiKey = ""
        username = ""
        apiURL = Self.defaultURL
        coreURL = Self.defaultCoreURL
        UserDefaults.standard.removeObject(forKey: "apiURL")
        UserDefaults.standard.removeObject(forKey: "coreURL")
        UserDefaults.standard.removeObject(forKey: "apiKey")
        UserDefaults.standard.removeObject(forKey: "username")
    }
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
