import AppKit
import SwiftUI

private enum SettingsTab: String, Hashable {
    case general
    case display
    case connection
    case notifications
    case about

    static let defaultWidth: CGFloat = 520
    static let windowHeight: CGFloat = 560

    var preferredWidth: CGFloat { Self.defaultWidth }
    var preferredHeight: CGFloat { Self.windowHeight }
}

struct SettingsView: View {
    @State private var selection: SettingsTab = .general

    @State var apiURL: String
    @State var coreURL: String
    @State var refreshSeconds: Double
    @State var launchAtLogin: Bool
    @State var notifyOnFreeGPU: Bool
    @State var notifyThreshold: Int
    @State var notifyClusterFilter: String
    @State var switcherShowsIcons: Bool
    @State var showOverviewTab: Bool
    @State var visibleClusterTabs: [String]
    @State var overviewSelectedClusters: [String]

    @State private var isVisibleClusterPopoverPresented = false
    @State private var isOverviewClusterPopoverPresented = false

    let availableClusters: [String]
    let onSave: (AppConfig) -> Void

    init(config: AppConfig, availableClusters: [String], onSave: @escaping (AppConfig) -> Void) {
        _apiURL = State(initialValue: config.apiURL)
        _coreURL = State(initialValue: config.coreURL)
        _refreshSeconds = State(initialValue: config.refreshInterval)
        _launchAtLogin = State(initialValue: config.launchAtLogin)
        _notifyOnFreeGPU = State(initialValue: config.notifyOnFreeGPU)
        _notifyThreshold = State(initialValue: config.notifyThreshold)
        _notifyClusterFilter = State(initialValue: config.notifyClusterFilter)
        _switcherShowsIcons = State(initialValue: config.switcherShowsIcons)
        _showOverviewTab = State(initialValue: config.showOverviewTab)
        _visibleClusterTabs = State(initialValue: config.visibleClusterTabs)
        _overviewSelectedClusters = State(initialValue: config.overviewSelectedClusters)
        self.availableClusters = AppConfig.orderedClusterOptions(available: availableClusters)
        self.onSave = onSave
    }

    var body: some View {
        TabView(selection: self.$selection) {
            SettingsScrollPane {
                SettingsSection {
                    Text("Menu bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    PreferenceToggleRow(
                        title: "Start at login",
                        subtitle: "Automatically opens GPUBar when you start your Mac.",
                        binding: self.$launchAtLogin)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Refresh interval")
                                .font(.body)
                            Text("How often GPUBar polls GPU status.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Picker("Refresh interval", selection: self.$refreshSeconds) {
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
            }
            .tabItem { Label("General", systemImage: "gearshape") }
            .tag(SettingsTab.general)

            SettingsScrollPane {
                SettingsSection(contentSpacing: 12) {
                    Text("Top switcher")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    PreferenceToggleRow(
                        title: "Show Overview tab",
                        subtitle: "Add the CodexBar-style Overview tab to the top switcher.",
                        binding: self.$showOverviewTab)
                    PreferenceToggleRow(
                        title: "Switcher shows icons",
                        subtitle: "Show cluster icons in the switcher instead of just the availability line.",
                        binding: self.$switcherShowsIcons)
                    self.clusterSelectorRow(
                        title: "Visible switcher tabs",
                        summary: self.visibleClusterSummary,
                        isPresented: self.$isVisibleClusterPopoverPresented,
                        content: { self.clusterSelectionPopover(kind: .visibleTabs) })
                    self.clusterSelectorRow(
                        title: "Overview tab clusters",
                        summary: self.overviewClusterSummary,
                        isPresented: self.$isOverviewClusterPopoverPresented,
                        content: { self.clusterSelectionPopover(kind: .overview) })
                }
            }
            .tabItem { Label("Display", systemImage: "square.grid.2x2") }
            .tag(SettingsTab.display)

            SettingsScrollPane {
                SettingsSection(contentSpacing: 12) {
                    Text("Pairing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dashboard URL")
                            .font(.body)
                        TextField("https://...", text: self.$apiURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auth Server URL")
                            .font(.body)
                        TextField("https://...", text: self.$coreURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("These are filled automatically when you pair from the dashboard.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .tabItem { Label("Connection", systemImage: "link") }
            .tag(SettingsTab.connection)

            SettingsScrollPane {
                SettingsSection(contentSpacing: 12) {
                    Text("Alerts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    PreferenceToggleRow(
                        title: "GPU availability alerts",
                        subtitle: "Notify when GPUs become available on a cluster.",
                        binding: self.$notifyOnFreeGPU)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Free GPU threshold")
                                .font(.body)
                            Text("Minimum free GPUs before a notification fires.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Stepper("\(self.notifyThreshold)+", value: self.$notifyThreshold, in: 1...16)
                            .frame(maxWidth: 110)
                    }
                    .disabled(!self.notifyOnFreeGPU)
                    .opacity(self.notifyOnFreeGPU ? 1 : 0.5)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cluster filter")
                                .font(.body)
                            Text("Only notify for clusters matching this text. Leave empty for all.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        TextField("all", text: self.$notifyClusterFilter)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 140)
                    }
                    .disabled(!self.notifyOnFreeGPU)
                    .opacity(self.notifyOnFreeGPU ? 1 : 0.5)
                }
            }
            .tabItem { Label("Notifications", systemImage: "bell") }
            .tag(SettingsTab.notifications)

            SettingsScrollPane {
                SettingsSection(contentSpacing: 12) {
                    Text("About")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    HStack {
                        Text("Version")
                            .font(.body)
                        Spacer()
                        Text("1.0.0")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    Text("GPUBar now uses the CodexBar switcher and display-pane patterns for cluster navigation.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .tabItem { Label("About", systemImage: "info.circle") }
            .tag(SettingsTab.about)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: SettingsTab.defaultWidth, height: SettingsTab.windowHeight)
        .onChange(of: self.apiURL) { _, _ in self.saveConfig() }
        .onChange(of: self.coreURL) { _, _ in self.saveConfig() }
        .onChange(of: self.refreshSeconds) { _, _ in self.saveConfig() }
        .onChange(of: self.launchAtLogin) { _, _ in self.saveConfig() }
        .onChange(of: self.notifyOnFreeGPU) { _, _ in self.saveConfig() }
        .onChange(of: self.notifyThreshold) { _, _ in self.saveConfig() }
        .onChange(of: self.notifyClusterFilter) { _, _ in self.saveConfig() }
        .onChange(of: self.switcherShowsIcons) { _, _ in self.saveConfig() }
        .onChange(of: self.showOverviewTab) { _, _ in self.saveConfig() }
        .onChange(of: self.visibleClusterTabs) { _, _ in self.saveConfig() }
        .onChange(of: self.overviewSelectedClusters) { _, _ in self.saveConfig() }
    }

    private func saveConfig() {
        var config = AppConfig()
        config.apiURL = self.apiURL
        config.coreURL = self.coreURL
        config.refreshInterval = self.refreshSeconds
        config.launchAtLogin = self.launchAtLogin
        config.notifyOnFreeGPU = self.notifyOnFreeGPU
        config.notifyThreshold = self.notifyThreshold
        config.notifyClusterFilter = self.notifyClusterFilter
        config.switcherShowsIcons = self.switcherShowsIcons
        config.showOverviewTab = self.showOverviewTab
        config.visibleClusterTabs = AppConfig.sanitizeClusterNames(self.visibleClusterTabs)
        config.overviewSelectedClusters = AppConfig.sanitizeClusterNames(self.overviewSelectedClusters)
        self.onSave(config)
    }

    private var clusterOptions: [String] {
        let combined = self.availableClusters.isEmpty ? AppConfig.preferredClusterOrder : self.availableClusters
        return AppConfig.orderedClusterOptions(available: combined)
    }

    private var visibleClusterSummary: String {
        let selected = self.clusterOptions.filter { self.visibleClusterTabs.contains($0) }
        return selected.isEmpty ? "No cluster tabs selected" : selected.joined(separator: ", ")
    }

    private var overviewClusterSummary: String {
        let selected = self.clusterOptions.filter { self.overviewSelectedClusters.contains($0) }
        if !self.showOverviewTab {
            return "Overview tab is hidden"
        }
        return selected.isEmpty ? "Overview will mirror visible tabs" : selected.joined(separator: ", ")
    }

    private enum ClusterSelectionKind {
        case visibleTabs
        case overview
    }

    @ViewBuilder
    private func clusterSelectorRow<PopoverContent: View>(
        title: String,
        summary: String,
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> PopoverContent)
        -> some View
    {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.body)
                Spacer(minLength: 0)
                Button("Configure…") {
                    isPresented.wrappedValue = true
                }
                .popover(isPresented: isPresented, arrowEdge: .bottom) {
                    content()
                }
            }

            Text(summary)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private func clusterSelectionPopover(kind: ClusterSelectionKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind == .visibleTabs ? "Choose switcher tabs" : "Choose Overview clusters")
                .font(.headline)
            Text(kind == .visibleTabs
                ? "These determine which cluster buttons appear beside Overview."
                : "These cards appear inside Overview in the same order as the switcher.")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(self.clusterOptions, id: \.self) { cluster in
                        Toggle(
                            isOn: Binding(
                                get: {
                                    switch kind {
                                    case .visibleTabs:
                                        return self.visibleClusterTabs.contains(cluster)
                                    case .overview:
                                        return self.overviewSelectedClusters.contains(cluster)
                                    }
                                },
                                set: { isSelected in
                                    self.updateSelection(kind: kind, cluster: cluster, isSelected: isSelected)
                                })) {
                            Text(AppConfig.displayName(for: cluster))
                                .font(.body)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(12)
        .frame(width: 300)
    }

    private func updateSelection(kind: ClusterSelectionKind, cluster: String, isSelected: Bool) {
        switch kind {
        case .visibleTabs:
            self.visibleClusterTabs = self.updatedClusterSelection(self.visibleClusterTabs, cluster: cluster, isSelected: isSelected)
        case .overview:
            self.overviewSelectedClusters = self.updatedClusterSelection(self.overviewSelectedClusters, cluster: cluster, isSelected: isSelected)
        }
    }

    private func updatedClusterSelection(_ current: [String], cluster: String, isSelected: Bool) -> [String] {
        var updated = AppConfig.sanitizeClusterNames(current)
        if isSelected {
            updated.append(cluster)
        } else {
            updated.removeAll { $0 == cluster }
        }
        let selectedSet = Set(updated)
        return self.clusterOptions.filter { selectedSet.contains($0) }
    }
}

@MainActor
private struct SettingsScrollPane<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                self.content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}

@MainActor
struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var binding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5.4) {
            Toggle(isOn: self.$binding) {
                Text(self.title)
                    .font(.body)
            }
            .toggleStyle(.checkbox)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
struct SettingsSection<Content: View>: View {
    let title: String?
    let caption: String?
    let contentSpacing: CGFloat
    private let content: () -> Content

    init(
        title: String? = nil,
        caption: String? = nil,
        contentSpacing: CGFloat = 14,
        @ViewBuilder content: @escaping () -> Content)
    {
        self.title = title
        self.caption = caption
        self.contentSpacing = contentSpacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: self.contentSpacing) {
                self.content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
