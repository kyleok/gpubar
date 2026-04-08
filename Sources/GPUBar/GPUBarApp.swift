import SwiftUI
import AppKit
import ServiceManagement
import Sparkle

@main
struct GPUBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var config = AppConfig()
    @State private var monitor: GPUMonitor?
    @State private var startupDone = false

    var body: some Scene {
        MenuBarExtra {
            if !config.isPaired || monitor?.keyInvalid == true {
                SetupView(
                    onQuit: { NSApplication.shared.terminate(nil) }
                )
            } else if let monitor = monitor {
                MenuBarView(
                    monitor: monitor,
                    config: config,
                    onSettings: { openSettings() },
                    onRefresh: { Task { await monitor.fetch() } },
                    onDisconnect: { handleDisconnect() },
                    onQuit: { NSApplication.shared.terminate(nil) }
                )
            } else {
                Text("Starting...")
                    .onAppear { attemptAutoStart() }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                if let monitor = monitor, config.isPaired {
                    Text("\(monitor.totalFree)")
                        .monospacedDigit()
                }
            }
            .onAppear { attemptAutoStart() }
        }
        .menuBarExtraStyle(.window)
    }

    private func attemptAutoStart() {
        guard !startupDone else { return }
        startupDone = true

        // Register deep link handler via AppDelegate
        appDelegate.onDeepLink = { url in handleDeepLink(url) }

        if config.isPaired {
            startMonitor()
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "gpubar", url.host == "configure" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []

        var updated = false
        if let api = items.first(where: { $0.name == "api" })?.value {
            config.apiURL = api
            updated = true
        }
        if let core = items.first(where: { $0.name == "core" })?.value {
            config.coreURL = core
            updated = true
        }
        if let key = items.first(where: { $0.name == "key" })?.value {
            config.apiKey = key
            updated = true
        }
        if let user = items.first(where: { $0.name == "user" })?.value {
            config.username = user
            updated = true
        }

        if updated {
            config.save()
            if config.isPaired {
                monitor?.stopPolling()
                monitor = nil
                startMonitor()
            }
        }
    }

    private func startMonitor() {
        guard config.isPaired else { return }
        if monitor == nil {
            monitor = GPUMonitor(config: config)
        }
        monitor?.startPolling()

        if config.notifyOnFreeGPU {
            NotificationManager.shared.requestPermission()
        }
    }

    private func handleDisconnect() {
        monitor?.stopPolling()
        monitor = nil
        config.disconnect()
    }

    private func openSettings() {
        appDelegate.showSettings(
            config: config,
            availableClusters: monitor?.clusters.map(\.id) ?? AppConfig.preferredClusterOrder) { updatedConfig in
            config.apiURL = updatedConfig.apiURL
            config.coreURL = updatedConfig.coreURL
            config.refreshInterval = updatedConfig.refreshInterval
            config.launchAtLogin = updatedConfig.launchAtLogin
            config.notifyOnFreeGPU = updatedConfig.notifyOnFreeGPU
            config.notifyThreshold = updatedConfig.notifyThreshold
            config.notifyClusterFilter = updatedConfig.notifyClusterFilter
            config.switcherShowsIcons = updatedConfig.switcherShowsIcons
            config.showOverviewTab = updatedConfig.showOverviewTab
            config.visibleClusterTabs = updatedConfig.visibleClusterTabs
            config.overviewSelectedClusters = updatedConfig.overviewSelectedClusters
            config.save()

            monitor?.stopPolling()
            monitor = GPUMonitor(config: config)
            monitor?.updateInterval(updatedConfig.refreshInterval)
            monitor?.startPolling()

            setLaunchAtLogin(updatedConfig.launchAtLogin)
            if updatedConfig.notifyOnFreeGPU {
                NotificationManager.shared.requestPermission()
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }
}

// MARK: - AppDelegate (deep links + settings window + Sparkle)

final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var settingsWindow: NSWindow?
    var onDeepLink: ((URL) -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register URL scheme handler — onOpenURL doesn't work in MenuBarExtra apps
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }
        DispatchQueue.main.async {
            self.onDeepLink?(url)
        }
    }

    func showSettings(config: AppConfig, availableClusters: [String], onSave: @escaping (AppConfig) -> Void) {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(config: config, availableClusters: availableClusters, onSave: { updated in
            onSave(updated)
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "GPUBar Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}

// MARK: - Setup View

struct SetupView: View {
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("GPUBar")
                .font(.headline)

            Text("Not connected")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Visit your GPU dashboard and click")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\"Link GPUBar\"")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Text("to connect automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Quit") { onQuit() }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding()
        .frame(width: 260)
    }
}
