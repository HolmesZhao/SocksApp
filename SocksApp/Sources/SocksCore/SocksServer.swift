import Foundation
import Network

public final class SocksServer: @unchecked Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case starting
        case running(host: String, port: UInt16)
        case failed(String)
        case stopped
    }

    private let port: UInt16
    private let queue = DispatchQueue(label: "SocksApp.SocksServer", qos: .userInitiated)
    private let log: @Sendable (String) -> Void
    private let connectionCountChanged: @Sendable (Int) -> Void
    private let authenticationMode: SocksAuthenticationMode
    private let stats: TrafficStats
    private var listener: NWListener?
    private var sessions: [SocksClientSession] = []
    private var activeSessions = 0

    public private(set) var state: State = .idle

    public init(
        port: UInt16 = 5_151,
        authenticationMode: SocksAuthenticationMode = .open,
        stats: TrafficStats,
        connectionCountChanged: @escaping @Sendable (Int) -> Void = { _ in },
        log: @escaping @Sendable (String) -> Void
    ) {
        self.port = port
        self.authenticationMode = authenticationMode
        self.stats = stats
        self.connectionCountChanged = connectionCountChanged
        self.log = log
    }

    public func start(advertisedHost: String) throws {
        guard listener == nil else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw SocksError.generalFailure
        }

        state = .starting
        let listener = try NWListener(using: .tcp, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state, advertisedHost: advertisedHost)
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        sessions.forEach { $0.cancel() }
        sessions.removeAll()
        activeSessions = 0
        connectionCountChanged(activeSessions)
        state = .stopped
        log("[SOCKS] Server stopped")
    }

    private func accept(_ connection: NWConnection) {
        activeSessions += 1
        connectionCountChanged(activeSessions)
        let session = SocksClientSession(client: connection, queue: queue, authenticationMode: authenticationMode, stats: stats, log: log) { [weak self] in
            self?.clientSessionDidFinish()
        }
        sessions.append(session)
        session.start()
    }

    private func clientSessionDidFinish() {
        activeSessions = max(0, activeSessions - 1)
        connectionCountChanged(activeSessions)
    }

    private func handleListenerState(_ listenerState: NWListener.State, advertisedHost: String) {
        switch listenerState {
        case .ready:
            state = .running(host: advertisedHost, port: port)
            log("[SOCKS] Starting server at \(advertisedHost):\(port)")
        case .failed(let error):
            state = .failed(error.localizedDescription)
            log("[SOCKS] Failed to start: \(error.localizedDescription)")
            stop()
        case .cancelled:
            state = .stopped
        default:
            break
        }
    }
}

private final class SocksClientSession: @unchecked Sendable {
    private let client: NWConnection
    private let queue: DispatchQueue
    private let authenticationMode: SocksAuthenticationMode
    private let stats: TrafficStats
    private let log: @Sendable (String) -> Void
    private let onFinish: @Sendable () -> Void
    private var target: NWConnection?
    private var udpRelay: SocksUDPRelay?
    private var didFinish = false

    init(
        client: NWConnection,
        queue: DispatchQueue,
        authenticationMode: SocksAuthenticationMode,
        stats: TrafficStats,
        log: @escaping @Sendable (String) -> Void,
        onFinish: @escaping @Sendable () -> Void
    ) {
        self.client = client
        self.queue = queue
        self.authenticationMode = authenticationMode
        self.stats = stats
        self.log = log
        self.onFinish = onFinish
    }

    func start() {
        client.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                self?.finish(.failed(error.localizedDescription))
            }
            if case .cancelled = state {
                self?.finish(.closedNormally("client connection cancelled"))
            }
        }
        client.start(queue: queue)
        readAuthenticationHeader()
    }

    func cancel() {
        finish(.closedNormally("server stopped session"))
    }

    private func finish(_ reason: SocksConnectionClosureReason) {
        guard !didFinish else { return }
        didFinish = true
        log(reason.logMessage)
        client.cancel()
        target?.cancel()
        udpRelay?.stop()
        onFinish()
    }

    private func readAuthenticationHeader() {
        client.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                finish(.failed("reading auth header: \(error.localizedDescription)"))
                return
            }
            guard let data, data.count == 2 else {
                finish(.closedNormally("client closed before auth header completed"))
                return
            }
            let methodsLength = Int(data[1])
            self.client.receive(minimumIncompleteLength: methodsLength, maximumLength: methodsLength) { [weak self] methods, _, _, error in
                guard let self else { return }
                if let error {
                    finish(.failed("reading auth methods: \(error.localizedDescription)"))
                    return
                }
                let packet = data + (methods ?? Data())
                do {
                    let response = try SocksHandshake.selectAuthenticationMethod(from: packet, mode: authenticationMode)
                    client.send(content: response, completion: .contentProcessed { [weak self] sendError in
                        guard let self else { return }
                        if let sendError {
                            finish(.failed("sending auth response: \(sendError.localizedDescription)"))
                        } else if response.last == 0x00 {
                            readRequest(accumulated: Data())
                        } else if response.last == 0x02 {
                            readUsernamePasswordAuthentication(accumulated: Data())
                        } else {
                            finish(.rejected("No supported authentication method"))
                        }
                    })
                } catch {
                    finish(.rejected("Invalid authentication request"))
                }
            }
        }
    }

    private func readUsernamePasswordAuthentication(accumulated: Data) {
        client.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                finish(.failed("reading username/password auth: \(error.localizedDescription)"))
                return
            }

            let packet = accumulated + (data ?? Data())
            guard case let .usernamePassword(username, password) = authenticationMode else {
                finish(.rejected("Username/password auth is not enabled"))
                return
            }

            do {
                let response = try SocksUsernamePasswordAuthentication.response(
                    for: packet,
                    username: username,
                    password: password
                )
                client.send(content: response, completion: .contentProcessed { [weak self] sendError in
                    guard let self else { return }
                    if let sendError {
                        finish(.failed("sending username/password auth response: \(sendError.localizedDescription)"))
                    } else if SocksUsernamePasswordAuthentication.isSuccess(response) {
                        readRequest(accumulated: Data())
                    } else {
                        finish(.rejected("Invalid username/password credentials"))
                    }
                })
            } catch SocksError.incomplete {
                readUsernamePasswordAuthentication(accumulated: packet)
            } catch {
                client.send(content: Data([0x01, 0x01]), completion: .contentProcessed { [weak self] _ in
                    self?.finish(.rejected("Invalid username/password authentication packet"))
                })
            }
        }
    }

    private func readRequest(accumulated: Data) {
        client.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                finish(.failed("reading request: \(error.localizedDescription)"))
                return
            }

            let packet = accumulated + (data ?? Data())
            do {
                let request = try SocksRequestParser.parse(packet)
                handle(request)
            } catch SocksError.incomplete {
                readRequest(accumulated: packet)
            } catch let socksError as SocksError {
                client.send(content: SocksReply.failure(socksError), completion: .contentProcessed { [weak self] _ in
                    self?.finish(.rejected("SOCKS request error: \(socksError)"))
                })
            } catch {
                client.send(content: SocksReply.failure(.generalFailure), completion: .contentProcessed { [weak self] _ in
                    self?.finish(.failed("unexpected request parsing error: \(error)"))
                })
            }
        }
    }

    private func handle(_ request: SocksRequest) {
        switch request.command {
        case .connect:
            connectToTCPDestination(request.destination)
        case .udpAssociate:
            startUDPAssociation(request.destination)
        }
    }

    private func startUDPAssociation(_ destination: SocksDestination) {
        do {
            let relay = SocksUDPRelay(queue: queue, stats: stats, log: log)
            let relayPort = try relay.start()
            udpRelay = relay
            log("[SOCKS] UDP_ASSOCIATE ready for \(destination.host):\(destination.port)")
            client.send(content: SocksReply.success(host: "0.0.0.0", port: relayPort), completion: .contentProcessed { [weak self] error in
                if let error {
                    self?.finish(.failed("sending UDP_ASSOCIATE response: \(error.localizedDescription)"))
                } else {
                    self?.holdUDPControlConnection()
                }
            })
        } catch {
            client.send(content: SocksReply.failure(.generalFailure), completion: .contentProcessed { [weak self] _ in
                self?.finish(.failed("UDP_ASSOCIATE failed: \(error)"))
            })
        }
    }

    private func holdUDPControlConnection() {
        client.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] _, _, isComplete, error in
            guard let self else { return }
            if let error {
                finish(.failed("UDP control connection failed: \(error.localizedDescription)"))
            } else if isComplete {
                finish(.closedNormally("UDP control connection closed"))
            } else {
                holdUDPControlConnection()
            }
        }
    }

    private func connectToTCPDestination(_ destination: SocksDestination) {
        guard let port = NWEndpoint.Port(rawValue: destination.port) else {
            client.send(content: SocksReply.failure(.generalFailure), completion: .contentProcessed { [weak self] _ in
                self?.finish(.rejected("invalid destination port: \(destination.port)"))
            })
            return
        }

        let outbound = NWConnection(host: NWEndpoint.Host(destination.host), port: port, using: .tcp)
        target = outbound
        outbound.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                log("[SOCKS] SOCKS connection: client -> \(destination.host):\(destination.port)")
                client.send(content: SocksReply.success(), completion: .contentProcessed { [weak self] error in
                    guard let self else { return }
                    if let error {
                        log("[SOCKS] Error sending CONNECT success: \(error.localizedDescription)")
                        finish(.failed("sending CONNECT success: \(error.localizedDescription)"))
                        return
                    }
                    pumpClientToTarget()
                    pumpTargetToClient()
                })
            case .failed(let error):
                client.send(content: SocksReply.failure(.generalFailure), completion: .contentProcessed { [weak self] _ in
                    self?.finish(.failed("connecting target \(destination.host):\(destination.port): \(error.localizedDescription)"))
                })
            case .cancelled:
                finish(.closedNormally("target connection cancelled"))
            default:
                break
            }
        }
        outbound.start(queue: queue)
    }

    private func pumpClientToTarget() {
        client.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1_024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty, let target {
                stats.addUpload(data.count)
                target.send(content: data, completion: .contentProcessed { [weak self] sendError in
                    guard let self else { return }
                    if let sendError {
                        finish(.failed("upload forwarding failed: \(sendError.localizedDescription)"))
                    } else if !isComplete && error == nil {
                        pumpClientToTarget()
                    } else if let error {
                        finish(.failed("client upload receive failed: \(error.localizedDescription)"))
                    } else if isComplete {
                        finish(.closedNormally("client finished upload stream"))
                    } else {
                        finish(.closedNormally("client upload stream closed"))
                    }
                })
            } else if let error {
                finish(.failed("client upload receive failed: \(error.localizedDescription)"))
            } else if isComplete {
                finish(.closedNormally("client closed upload stream"))
            } else {
                finish(.closedNormally("client upload stream ended"))
            }
        }
    }

    private func pumpTargetToClient() {
        target?.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1_024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                stats.addDownload(data.count)
                client.send(content: data, completion: .contentProcessed { [weak self] sendError in
                    guard let self else { return }
                    if let sendError {
                        finish(.failed("download forwarding failed: \(sendError.localizedDescription)"))
                    } else if !isComplete && error == nil {
                        pumpTargetToClient()
                    } else if let error {
                        finish(.failed("target download receive failed: \(error.localizedDescription)"))
                    } else if isComplete {
                        finish(.closedNormally("target finished download stream"))
                    } else {
                        finish(.closedNormally("target download stream closed"))
                    }
                })
            } else if let error {
                finish(.failed("target download receive failed: \(error.localizedDescription)"))
            } else if isComplete {
                finish(.closedNormally("target closed download stream"))
            } else {
                finish(.closedNormally("target download stream ended"))
            }
        }
    }
}
