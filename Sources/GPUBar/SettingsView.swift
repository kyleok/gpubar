import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State var apiURL: String
    @State var coreURL: String
    @State var refreshSeconds: Double
    @State var launchAtLogin: Bool
    @State var notifyOnFreeGPU: Bool
    @State var notifyThreshold: Int
    @State var notifyClusterFilter: String
    let onSave: (AppConfig) -> Void

    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        _apiURL = State(initialValue: config.apiURL)
        _coreURL = State(initialValue: config.coreURL)
        _refreshSeconds = State(initialValue: config.refreshInterval)
        _launchAtLogin = State(initialValue: config.launchAtLogin)
        _notifyOnFreeGPU = State(initialValue: config.notifyOnFreeGPU)
        _notifyThreshold = State(initialValue: config.notifyThreshold)
        _notifyClusterFilter = State(initialValue: config.notifyClusterFilter)
        self.onSave = onSave
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - General
                SettingsSection {
                    SectionHeader("General")
                    PreferenceToggleRow(
                        title: "Start at login",
                        subtitle: "Automatically opens GPUBar when you start your Mac.",
                        isOn: $launchAtLogin
                    )

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Refresh interval")
                                .font(.body)
                            Text("How often GPUBar polls GPU status.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Picker("", selection: $refreshSeconds) {
                            Text("30 sec").tag(30.0)
                            Text("1 min").tag(60.0)
                            Text("2 min").tag(120.0)
                            Text("5 min").tag(300.0)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 120)
                    }
                }

                Divider()

                // MARK: - Connection
                SettingsSection {
                    SectionHeader("Connection")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dashboard URL")
                            .font(.body)
                        TextField("https://...", text: $apiURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auth Server URL")
                            .font(.body)
                        TextField("https://...", text: $coreURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("These are automatically configured when you pair via your dashboard.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // MARK: - Notifications
                SettingsSection {
                    SectionHeader("Notifications")
                    PreferenceToggleRow(
                        title: "GPU availability alerts",
                        subtitle: "Notify when GPUs become available on a cluster.",
                        isOn: $notifyOnFreeGPU
                    )
                    if notifyOnFreeGPU {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Free GPU threshold")
                                    .font(.body)
                                Text("Minimum free GPUs before notification fires.")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Stepper("\(notifyThreshold)+", value: $notifyThreshold, in: 1...16)
                                .frame(maxWidth: 100)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cluster filter")
                                    .font(.body)
                                Text("Only notify for clusters matching this text. Leave empty for all.")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            TextField("all", text: $notifyClusterFilter)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)
                        }
                    }
                }

                Divider()

                // MARK: - About
                SettingsSection {
                    SectionHeader("About")
                    HStack {
                        Text("Version")
                            .font(.body)
                        Spacer()
                        Text("1.0.0")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 420, height: 480)
        .onChange(of: apiURL) { _, _ in saveConfig() }
        .onChange(of: coreURL) { _, _ in saveConfig() }
        .onChange(of: refreshSeconds) { _, _ in saveConfig() }
        .onChange(of: launchAtLogin) { _, _ in saveConfig() }
        .onChange(of: notifyOnFreeGPU) { _, _ in saveConfig() }
        .onChange(of: notifyThreshold) { _, _ in saveConfig() }
        .onChange(of: notifyClusterFilter) { _, _ in saveConfig() }
    }

    private func saveConfig() {
        var config = AppConfig()
        config.apiURL = apiURL
        config.coreURL = coreURL
        config.refreshInterval = refreshSeconds
        config.launchAtLogin = launchAtLogin
        config.notifyOnFreeGPU = notifyOnFreeGPU
        config.notifyThreshold = notifyThreshold
        config.notifyClusterFilter = notifyClusterFilter
        onSave(config)
    }
}

// MARK: - Reusable Components

struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.body)
            }
            .toggleStyle(.checkbox)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
