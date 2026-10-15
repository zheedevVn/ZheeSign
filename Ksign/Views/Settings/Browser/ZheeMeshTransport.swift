import CryptoKit
import Foundation
import MultipeerConnectivity
import Security

/// A mesh message received over the local peer network.
struct ZheeMeshMessage {
    let id: String
    let from: String // sender Nostr pubkey hex (shared identity across transports)
    let name: String
    let text: String
    let date: Date
    /// Voice clip bytes (PTT), if this is a voice message.
    var voice: Data?
}

/// Offline nearby chat over MultipeerConnectivity (Bluetooth + local Wi-Fi).
/// Peers auto-discover, auto-accept invitations, and relay (flood) messages
/// they receive, so a message hops across nearby devices up to 3 times.
/// Every hop is end-to-end encrypted: ephemeral ECDH + HKDF + ChaChaPoly,
/// with a fresh ephemeral keypair per session. No account, no server, no internet.
final class ZheeMeshTransport: NSObject, ObservableObject {
    static let serviceType = "zheechat"
    private static let maxHops = 3

    @Published private(set) var connectedPeerNames: [String] = []

    var onMessage: ((ZheeMeshMessage) -> Void)?

    private var peerID: MCPeerID!
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var seenIDs = Set<String>()
    private var running = false

    /// Ephemeral keypair for this session (rotated on every start).
    private var ephemeralSecret = Data()
    private var ephemeralPubkey = Data()
    /// Per-peer session keys, established by the pubkey handshake.
    private var sessionKeys = [MCPeerID: SymmetricKey]()
    /// Plaintext envelopes queued while a peer's session key is not ready yet.
    private var pending = [MCPeerID: [Data]]()

    override init() {
        super.init()
    }

    func start() {
        guard !running else { return }
        running = true
        let identity = ZheeNostrIdentity.shared
        let suffix = String(identity.publicKeyHex.prefix(4))
        var name = "\(identity.displayName)#\(suffix)"
        while name.utf8.count > 60 { name.removeLast() }
        peerID = MCPeerID(displayName: name)
        // Fresh ephemeral keypair per session.
        var secret = Data(count: 32)
        _ = secret.withUnsafeMutableBytes { SecRandomCopyBytes(nil, 32, $0.baseAddress!) }
        ephemeralSecret = secret
        ephemeralPubkey = ZheeSecp256k1.publicKey(forSecret: secret) ?? Data()
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        self.advertiser = advertiser
        advertiser.startAdvertisingPeer()
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
    }

    func stop() {
        running = false
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        seenIDs.removeAll()
        sessionKeys.removeAll()
        pending.removeAll()
        ephemeralSecret = Data()
        ephemeralPubkey = Data()
        DispatchQueue.main.async { self.connectedPeerNames = [] }
    }

    /// Rebuilds the peer identity (e.g. after the display name changed).
    func restart() {
        stop()
        start()
    }

    /// Broadcasts a message to all connected peers. Returns the message so
    /// the caller can echo it locally; nil if encoding failed.
    @discardableResult
    func broadcast(text: String) -> ZheeMeshMessage? {
        broadcastEnvelope(text: text, voice: nil)
    }

    /// Broadcasts a voice clip (PTT) to all connected peers.
    @discardableResult
    func broadcastVoice(_ audio: Data) -> ZheeMeshMessage? {
        broadcastEnvelope(text: "🎤 Tin nhắn thoại", voice: audio.base64EncodedString())
    }

    private func broadcastEnvelope(text: String, voice: String?) -> ZheeMeshMessage? {
        guard let session, !session.connectedPeers.isEmpty else {
            // No peers yet: still return a local message so the UI shows it.
            return makeLocalMessage(text: text, id: UUID().uuidString)
        }
        let envelope = Envelope(
            id: UUID().uuidString,
            from: ZheeNostrIdentity.shared.publicKeyHex,
            name: ZheeNostrIdentity.shared.displayName,
            text: text, ts: Date().timeIntervalSince1970, hops: 0, voice: voice
        )
        guard let data = try? JSONEncoder().encode(envelope) else { return nil }
        sendEncrypted(data, to: session.connectedPeers)
        return ZheeMeshMessage(
            id: envelope.id, from: envelope.from, name: envelope.name,
            text: envelope.text, date: Date(timeIntervalSince1970: envelope.ts),
            voice: voice.flatMap { Data(base64Encoded: $0) }
        )
    }

    private func makeLocalMessage(text: String, id: String) -> ZheeMeshMessage {
        ZheeMeshMessage(
            id: id, from: ZheeNostrIdentity.shared.publicKeyHex,
            name: ZheeNostrIdentity.shared.displayName,
            text: text, date: Date(), voice: nil
        )
    }

    // MARK: - E2EE handshake + encrypted send

    private func sendKey(to peer: MCPeerID) {
        guard let session else { return }
        let wire = WireEnvelope(kind: "key", payload: ephemeralPubkey.map { String(format: "%02x", $0) }.joined())
        guard let data = try? JSONEncoder().encode(wire) else { return }
        try? session.send(data, toPeers: [peer], with: .reliable)
    }

    private func sendEncrypted(_ plaintext: Data, to peers: [MCPeerID]) {
        guard let session else { return }
        for peer in peers {
            if let key = sessionKeys[peer] {
                guard let sealed = ZheeMeshCrypto.seal(plaintext, key: key),
                      let wire = try? JSONEncoder().encode(WireEnvelope(kind: "msg", payload: sealed.base64EncodedString())) else { continue }
                try? session.send(wire, toPeers: [peer], with: .reliable)
            } else {
                // No session key yet: queue and (re)send our pubkey.
                pending[peer, default: []].append(plaintext)
                sendKey(to: peer)
            }
        }
    }

    private func handleKey(_ payload: String, fromPeer peer: MCPeerID) {
        guard let theirPub = Data(hex: payload),
              let shared = ZheeSecp256k1.sharedSecret(secret: ephemeralSecret, publicKey: theirPub) else { return }
        let isNew = sessionKeys[peer] == nil
        sessionKeys[peer] = ZheeMeshCrypto.deriveKey(sharedSecret: shared)
        // Flush anything queued while the key was not ready.
        if let queued = pending.removeValue(forKey: peer) {
            for plaintext in queued {
                sendEncrypted(plaintext, to: [peer])
            }
        }
        // If this peer's key arrived first (they initiated), answer with ours
        // so they can derive the same session key.
        if isNew { sendKey(to: peer) }
    }

    private func handleData(_ data: Data, fromPeer peer: MCPeerID) {
        guard let wire = try? JSONDecoder().decode(WireEnvelope.self, from: data) else { return }
        if wire.kind == "key" {
            handleKey(wire.payload, fromPeer: peer)
            return
        }
        guard wire.kind == "msg",
              let key = sessionKeys[peer],
              let box = Data(base64Encoded: wire.payload),
              let plaintext = ZheeMeshCrypto.open(box, key: key),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: plaintext),
              !seenIDs.contains(envelope.id) else {
            // No session key yet (or undecryptable): ask for a handshake.
            if wire.kind == "msg", sessionKeys[peer] == nil { sendKey(to: peer) }
            return
        }
        seenIDs.insert(envelope.id)
        if seenIDs.count > 2000 { seenIDs.removeAll() }
        let message = ZheeMeshMessage(
            id: envelope.id, from: envelope.from, name: envelope.name,
            text: envelope.text, date: Date(timeIntervalSince1970: envelope.ts),
            voice: envelope.voice.flatMap { Data(base64Encoded: $0) }
        )
        DispatchQueue.main.async { self.onMessage?(message) }
        // Flood to the rest of the mesh, up to maxHops. Each next hop is
        // re-encrypted with that peer's own session key.
        guard envelope.hops < Self.maxHops,
              let session, !session.connectedPeers.isEmpty else { return }
        var relayed = envelope
        relayed.hops += 1
        guard let relayData = try? JSONEncoder().encode(relayed) else { return }
        let others = session.connectedPeers.filter { $0 != peer }
        guard !others.isEmpty else { return }
        sendEncrypted(relayData, to: others)
    }

    private func refreshPeers() {
        let names = (session?.connectedPeers ?? []).map { $0.displayName }
        DispatchQueue.main.async { self.connectedPeerNames = names }
    }

    private struct Envelope: Codable {
        var id: String
        var from: String
        var name: String
        var text: String
        var ts: TimeInterval
        var hops: Int
        /// Base64 AAC clip, if this is a voice (PTT) message.
        var voice: String?
    }

    private struct WireEnvelope: Codable {
        var kind: String // "key" | "msg"
        var payload: String
    }
}

extension ZheeMeshTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        refreshPeers()
        if state == .connected {
            sendKey(to: peerID)
        } else if state == .notConnected {
            sessionKeys.removeValue(forKey: peerID)
            pending.removeValue(forKey: peerID)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handleData(data, fromPeer: peerID)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension ZheeMeshTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
}

extension ZheeMeshTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
