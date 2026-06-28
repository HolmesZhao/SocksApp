import AVFoundation
import Network
import Security
import SwiftUI
import UIKit

@MainActor
final class SocksAppModel: ObservableObject {
    static let shared = SocksAppModel()

    @Published private(set) var statusText = "Not Running"
    @Published private(set) var statsText = "↑ 0 B (0 B/s) ↓ 0 B (0 B/s)"
    @Published private(set) var host = "127.0.0.1"
    @Published private(set) var port: UInt16 = 5_151
    @Published private(set) var uptimeText = "00:00:00"
    @Published private(set) var uploadText = "0 B"
    @Published private(set) var downloadText = "0 B"
    @Published private(set) var uploadSpeedText = "0 B/s"
    @Published private(set) var downloadSpeedText = "0 B/s"
    @Published private(set) var activeConnections = 0
    @Published private(set) var logEntries: [LogEntry] = []
    @Published var portDraft = "5151"
    @Published var portErrorMessage: String?
    @Published private(set) var portStatusMessage = L10n.string("port.status.restart_after_save")
    @Published private(set) var isOpenAccessEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKey.openAccessEnabled)
    @Published private(set) var proxyToken = ProxyToken.generate()
    @Published var showsNoNetworkAlert = false

    let proxyUsername = "socks"

    private let trafficStats = TrafficStats()
    private let logStore = LogStore(maxLines: 1_000)
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "SocksApp.NetworkPathMonitor")
    private var server: SocksServer?
    private var statsTimer: Timer?
    private var networkPathRefreshTask: Task<Void, Never>?
    private let audioKeeper = BackgroundAudioKeeper()
    private var didStart = false
    private var startedAt: Date?

    private init() {
        server = makeServer(port: port)
        startNetworkPathMonitor()
    }

    var isRunning: Bool {
        statusText.hasPrefix("Running")
    }

    var authenticationMode: SocksAuthenticationMode {
        if isOpenAccessEnabled {
            return .open
        }
        return .usernamePassword(username: proxyUsername, password: proxyToken)
    }

    var proxyURLString: String {
        if isOpenAccessEnabled {
            return "socks5://\(host):\(port)"
        }
        return "socks5://\(proxyUsername):\(proxyToken)@\(host):\(port)"
    }

    var accessModeText: String {
        isOpenAccessEnabled ? L10n.string("access.mode.open") : L10n.string("access.mode.authenticated")
    }

    func toggleServer() {
        if isRunning {
            stopServer()
        } else {
            startIfNeeded()
        }
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        appendLog("[SOCKS] View loaded")
        appendLog("[SOCKS] Initializing SOCKS server on port \(port)")
        startStatsTimer()
        startBackgroundAudio()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let ipAddress = NetworkInterfaceProvider.deviceIPAddress { message in
                Task { @MainActor in
                    self.appendLog(message)
                }
            }

            Task { @MainActor in
                if ipAddress == "127.0.0.1" {
                    self.appendLog("[SOCKS] No matching interface found, using fallback IP address")
                    self.appendLog("[SOCKS] Stopping server due to no valid interface")
                    self.statusText = "Not Running - No Network Interface"
                    self.showsNoNetworkAlert = true
                    self.audioKeeper.stop()
                    return
                }

                do {
                    try self.server?.start(advertisedHost: ipAddress)
                    self.host = ipAddress
                    self.startedAt = Date()
                    self.statusText = "Running at \(ipAddress):\(self.port)"
                } catch {
                    self.statusText = "Failed to start: \(error.localizedDescription)"
                    self.appendLog("[SOCKS] Failed to start: \(error.localizedDescription)")
                }
            }
        }
    }

    func stopServer() {
        server?.stop()
        audioKeeper.stop()
        activeConnections = 0
        startedAt = nil
        uptimeText = "00:00:00"
        statusText = "Not Running"
        didStart = false
        portStatusMessage = L10n.string("port.status.stopped")
    }

    func regenerateProxyToken() {
        proxyToken = ProxyToken.generate()
        isOpenAccessEnabled = false
        UserDefaults.standard.set(false, forKey: UserDefaultsKey.openAccessEnabled)
        restartServerForAccessChange(message: L10n.string("auth.token_regenerated.restart"))
    }

    func setOpenAccess(_ isEnabled: Bool) {
        guard isOpenAccessEnabled != isEnabled else { return }
        isOpenAccessEnabled = isEnabled
        UserDefaults.standard.set(isOpenAccessEnabled, forKey: UserDefaultsKey.openAccessEnabled)
        restartServerForAccessChange(message: isEnabled ? L10n.string("auth.open_mode.restart") : L10n.string("auth.auth_mode.restart"))
    }

    @discardableResult
    func applyPortChange() -> Bool {
        guard let parsedPort = SocksPort.parse(portDraft) else {
            portErrorMessage = L10n.string("port.error.invalid")
            portStatusMessage = L10n.string("port.status.invalid")
            return false
        }

        portErrorMessage = nil
        portDraft = String(parsedPort)
        guard parsedPort != port else {
            portStatusMessage = L10n.string("port.status.unchanged")
            return true
        }

        appendLog("[SOCKS] Updating listen port from \(port) to \(parsedPort)")
        port = parsedPort
        server?.stop()
        activeConnections = 0
        startedAt = nil
        statusText = "Restarting on port \(parsedPort)"
        server = makeServer(port: parsedPort)
        didStart = false
        startIfNeeded()
        portStatusMessage = L10n.string("port.status.saved_restart")
        return true
    }

    func acknowledgeNoNetworkAlert() {
        statusText = "Not Running - No Network Interface"
        server?.stop()
        audioKeeper.stop()
        activeConnections = 0
        startedAt = nil
        uptimeText = "00:00:00"
        didStart = false
        portStatusMessage = L10n.string("port.status.no_network_retry")
    }

    func appendLog(_ message: String) {
        let entry = logStore.append(message)
        logEntries = logStore.entries
        print("[\(entry.date)] \(entry.message)")
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            appendLog("[SOCKS] Scene became active")
        case .inactive:
            appendLog("[SOCKS] Scene became inactive")
        case .background:
            appendLog("[SOCKS] Scene entered background")
        @unknown default:
            appendLog("[SOCKS] Scene changed to unknown phase")
        }
    }

    private func startNetworkPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in
                self?.scheduleNetworkPathRefresh()
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private func scheduleNetworkPathRefresh() {
        networkPathRefreshTask?.cancel()
        networkPathRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.handleNetworkPathChange()
        }
    }

    private func handleNetworkPathChange() {
        let newHost = NetworkInterfaceProvider.deviceIPAddress { [weak self] message in
            Task { @MainActor in
                self?.appendLog(message)
            }
        }

        guard newHost != "127.0.0.1" else {
            handleUnavailableNetworkAfterPathChange()
            return
        }

        guard newHost != host else {
            appendLog("[SOCKS] Network path changed, IP address unchanged: \(newHost)")
            return
        }

        let previousHost = host
        host = newHost
        appendLog("[SOCKS] Network IP changed from \(previousHost) to \(newHost)")

        guard didStart else {
            portStatusMessage = L10n.string("network.status.ready")
            return
        }

        restartServerForNetworkChange(advertisedHost: newHost)
    }

    private func startStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStats()
            }
        }
    }

    private func refreshStats() {
        let snapshot = trafficStats.snapshot()
        uploadText = ByteFormatter.formatBytes(snapshot.uploadBytes)
        downloadText = ByteFormatter.formatBytes(snapshot.downloadBytes)
        uploadSpeedText = ByteFormatter.formatSpeed(snapshot.uploadBytesPerSecond)
        downloadSpeedText = ByteFormatter.formatSpeed(snapshot.downloadBytesPerSecond)
        statsText = "↑ \(uploadText) (\(uploadSpeedText)) ↓ \(downloadText) (\(downloadSpeedText))"
        uptimeText = formattedUptime(now: Date())
    }

    private func startBackgroundAudio() {
        appendLog("[SOCKS] Setting up background audio")
        audioKeeper.start { [weak self] message in
            Task { @MainActor in
                self?.appendLog(message)
            }
        }
    }

    private func makeServer(port: UInt16) -> SocksServer {
        SocksServer(
            port: port,
            authenticationMode: authenticationMode,
            stats: trafficStats,
            connectionCountChanged: { [weak self] count in
                Task { @MainActor in
                    self?.activeConnections = count
                }
            },
            log: { [weak self] message in
                Task { @MainActor in
                    self?.appendLog(message)
                }
            }
        )
    }

    private func restartServerForNetworkChange(advertisedHost: String) {
        appendLog("[SOCKS] Restarting server after network path change")
        portStatusMessage = L10n.string("network.status.restart")
        server?.stop()
        activeConnections = 0
        startedAt = nil
        statusText = L10n.string("status.network_restarting")
        server = makeServer(port: port)

        do {
            try server?.start(advertisedHost: advertisedHost)
            startedAt = Date()
            statusText = "Running at \(advertisedHost):\(port)"
        } catch {
            didStart = false
            statusText = "Failed to start: \(error.localizedDescription)"
            appendLog("[SOCKS] Failed to restart after network change: \(error.localizedDescription)")
        }
    }

    private func handleUnavailableNetworkAfterPathChange() {
        guard didStart || isRunning else { return }
        appendLog("[SOCKS] Network path changed, no valid IP address is available")
        server?.stop()
        audioKeeper.stop()
        activeConnections = 0
        startedAt = nil
        uptimeText = "00:00:00"
        statusText = "Not Running - No Network Interface"
        showsNoNetworkAlert = true
        portStatusMessage = L10n.string("port.status.no_network_retry")
    }

    private func restartServerForAccessChange(message: String) {
        appendLog("[SOCKS] Updating authentication mode to \(accessModeText)")
        portStatusMessage = message
        let shouldRestart = didStart
        server?.stop()
        activeConnections = 0
        startedAt = nil
        server = makeServer(port: port)
        guard shouldRestart else {
            statusText = "Not Running"
            uptimeText = "00:00:00"
            return
        }
        statusText = "Restarting authentication"
        didStart = false
        startIfNeeded()
    }

    private func formattedUptime(now: Date) -> String {
        guard let startedAt else { return "00:00:00" }
        let seconds = max(Int(now.timeIntervalSince(startedAt)), 0)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }
}

private enum ProxyToken {
    static func generate() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")
        var bytes = [UInt8](repeating: 0, count: 12)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).uppercased()
        }
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }
}

private enum UserDefaultsKey {
    static let openAccessEnabled = "openAccessEnabled"
}
