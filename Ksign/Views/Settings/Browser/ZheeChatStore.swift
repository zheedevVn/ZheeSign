import Combine
import Foundation

enum ZheeChatChannel: String, CaseIterable, Identifiable {
    case mesh = "mesh"
    case nostr = "nostr"
    case dm = "dm"
    case geo = "geo"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mesh: return "Mesh gần"
        case .nostr: return "Nostr công khai"
        case .dm: return "DM riêng"
        case .geo: return "Gần tôi"
        }
    }

    var subtitle: String {
        switch self {
        case .mesh: return "Offline · Bluetooth + Wi-Fi cục bộ"
        case .nostr: return "Online · Relay toàn cầu"
        case .dm: return "Mã hóa NIP-04 · Chỉ 2 người đọc được"
        case .geo: return "Kênh theo vị trí · Bán kính ~5km"
        }
    }
}

/// One chat message in a ZheeChat channel.
struct ZheeChatMessage: Identifiable, Codable {
    let id: String
    let channel: String
    let senderID: String // Nostr pubkey hex
    let senderName: String
    let text: String
    let timestamp: TimeInterval
    let isMine: Bool
    /// DM peer pubkey hex (channel "dm" only).
    let peerID: String?
    /// True if this message carries a voice clip (audio lives in memory only).
    let hasVoice: Bool

    var date: Date { Date(timeIntervalSince1970: timestamp) }

    init(id: String, channel: String, senderID: String, senderName: String, text: String, timestamp: TimeInterval, isMine: Bool, peerID: String? = nil, hasVoice: Bool = false) {
        self.id = id
        self.channel = channel
        self.senderID = senderID
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isMine = isMine
        self.peerID = peerID
        self.hasVoice = hasVoice
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        channel = try c.decode(String.self, forKey: .channel)
        senderID = try c.decode(String.self, forKey: .senderID)
        senderName = try c.decode(String.self, forKey: .senderName)
        text = try c.decode(String.self, forKey: .text)
        timestamp = try c.decode(TimeInterval.self, forKey: .timestamp)
        isMine = try c.decode(Bool.self, forKey: .isMine)
        // Added later: old persisted messages have no peerID / hasVoice.
        peerID = try c.decodeIfPresent(String.self, forKey: .peerID)
        hasVoice = try c.decodeIfPresent(Bool.self, forKey: .hasVoice) ?? false
    }
}

/// Owns the two ZheeChat channels (local mesh + global Nostr), merges
/// inbound traffic, dedupes by id, and persists recent messages to disk.
final class ZheeChatStore: ObservableObject {
    static let shared = ZheeChatStore()

    @Published private(set) var messages: [ZheeChatMessage] = []
    @Published private(set) var meshPeerCount = 0
    @Published private(set) var nostrRelayCount = 0
    @Published private(set) var nostrConnected = false
    @Published private(set) var currentGeohash: String?
    @Published private(set) var profiles: [String: ZheeNostrProfile] = [:]
    /// Text handed over by the Share Extension (via zheesign://zheechat-share),
    /// consumed by ZheeChatView into the composer draft.
    @Published var pendingShareText: String?

    /// Display name for a pubkey: profile name if known, else short npub.
    func displayName(for pubkey: String) -> String {
        if let name = profiles[pubkey]?.name, !name.isEmpty { return name }
        return "npub1" + String(pubkey.prefix(8))
    }

    let mesh = ZheeMeshTransport()
    let nostr = ZheeNostrClient()

    private var seenIDs = Set<String>()
    private static let maxMessages = 500
    /// Voice clips in memory only (never persisted to disk).
    private var voiceData = [String: Data]()

    func voiceData(for id: String) -> Data? { voiceData[id] }

    private init() {
        messages = Self.loadMessages()
        seenIDs = Set(messages.map { $0.id })
        mesh.onMessage = { [weak self] msg in
            self?.append(
                id: msg.id, channel: .mesh, senderID: msg.from,
                senderName: msg.name, text: msg.text, date: msg.date, isMine: false,
                voice: msg.voice
            )
        }
        nostr.onEvent = { [weak self] event in
            guard let self else { return }
            let identity = ZheeNostrIdentity.shared
            let isMine = event.pubkey == identity.publicKeyHex
            if !isMine { nostr.requestProfile(pubkey: event.pubkey) }
            // Geohash-tagged events belong to the nearby channel, and only
            // if they match the currently selected geohash (relays may
            // ignore the #g filter, so filter client-side too).
            if let g = event.tags.first(where: { $0.first == "g" })?.dropFirst().first {
                guard g == currentGeohash else { return }
                append(
                    id: event.id, channel: .geo, senderID: event.pubkey,
                    senderName: isMine ? identity.displayName : displayName(for: event.pubkey),
                    text: event.content, date: event.date, isMine: isMine
                )
            } else {
                append(
                    id: event.id, channel: .nostr, senderID: event.pubkey,
                    senderName: isMine ? identity.displayName : displayName(for: event.pubkey),
                    text: event.content, date: event.date, isMine: isMine
                )
            }
        }
        nostr.onDM = { [weak self] event, plaintext in
            guard let self else { return }
            nostr.requestProfile(pubkey: event.pubkey)
            append(
                id: event.id, channel: .dm, senderID: event.pubkey,
                senderName: displayName(for: event.pubkey),
                text: plaintext, date: event.date, isMine: false,
                peerID: event.pubkey
            )
        }
        mesh.$connectedPeerNames
            .map { $0.count }
            .receive(on: DispatchQueue.main)
            .assign(to: &$meshPeerCount)
        nostr.$connectedRelayURLs
            .map { !$0.isEmpty }
            .receive(on: DispatchQueue.main)
            .assign(to: &$nostrConnected)
        nostr.$connectedRelayURLs
            .map { $0.count }
            .receive(on: DispatchQueue.main)
            .assign(to: &$nostrRelayCount)
        nostr.$profiles
            .receive(on: DispatchQueue.main)
            .assign(to: &$profiles)
    }

    func start() {
        mesh.start()
        nostr.start()
    }

    func stop() {
        mesh.stop()
        nostr.stop()
    }

    func messages(in channel: ZheeChatChannel) -> [ZheeChatMessage] {
        messages.filter { $0.channel == channel.rawValue }
    }

    func setGeohash(_ geohash: String?) {
        currentGeohash = geohash
        nostr.setGeoFilter(geohash)
    }

    func send(text: String, channel: ZheeChatChannel) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let identity = ZheeNostrIdentity.shared
        switch channel {
        case .mesh:
            guard let msg = mesh.broadcast(text: trimmed) else { return }
            append(
                id: msg.id, channel: .mesh, senderID: msg.from,
                senderName: msg.name, text: msg.text, date: msg.date, isMine: true
            )
        case .nostr:
            guard let event = nostr.publish(text: trimmed) else { return }
            append(
                id: event.id, channel: .nostr, senderID: event.pubkey,
                senderName: identity.displayName, text: event.content,
                date: event.date, isMine: true
            )
        case .dm:
            break // DMs go through sendDM(toPeer:) with an explicit peer.
        case .geo:
            guard let geohash = currentGeohash,
                  let event = nostr.publishGeo(text: trimmed, geohash: geohash) else { return }
            append(
                id: event.id, channel: .geo, senderID: identity.publicKeyHex,
                senderName: identity.displayName, text: trimmed,
                date: event.date, isMine: true
            )
        }
    }

    func clear(channel: ZheeChatChannel) {
        messages.removeAll { $0.channel == channel.rawValue }
        seenIDs = Set(messages.map { $0.id })
        save()
    }

    func clearDM(peer: String) {
        messages.removeAll { $0.channel == ZheeChatChannel.dm.rawValue && $0.peerID == peer }
        seenIDs = Set(messages.map { $0.id })
        save()
    }

    /// Emergency wipe: all history + geohash filter, then reconnect with
    /// the fresh identity (the caller wipes the identity first).
    func wipeAll() {
        messages.removeAll()
        seenIDs.removeAll()
        currentGeohash = nil
        nostr.setGeoFilter(nil)
        save()
        mesh.restart()
        nostr.stop()
        nostr.start()
    }

    /// DM conversations, most recent first.
    var dmConversations: [(peer: String, lastMessage: ZheeChatMessage)] {
        var byPeer = [String: ZheeChatMessage]()
        for msg in messages where msg.channel == ZheeChatChannel.dm.rawValue {
            guard let peer = msg.peerID else { continue }
            if let current = byPeer[peer] {
                if msg.timestamp > current.timestamp { byPeer[peer] = msg }
            } else {
                byPeer[peer] = msg
            }
        }
        return byPeer.map { ($0.key, $0.value) }.sorted { $0.1.timestamp > $1.1.timestamp }
    }

    func dmMessages(peer: String) -> [ZheeChatMessage] {
        messages.filter { $0.channel == ZheeChatChannel.dm.rawValue && $0.peerID == peer }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func sendDM(text: String, toPeer peer: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let identity = ZheeNostrIdentity.shared
        guard let event = nostr.publishDM(text: trimmed, toPubkeyHex: peer) else { return }
        append(
            id: event.id, channel: .dm, senderID: identity.publicKeyHex,
            senderName: identity.displayName, text: trimmed,
            date: event.date, isMine: true, peerID: peer
        )
    }

    func sendVoice(_ audio: Data) {
        guard let msg = mesh.broadcastVoice(audio) else { return }
        append(
            id: msg.id, channel: .mesh, senderID: msg.from,
            senderName: msg.name, text: msg.text, date: msg.date, isMine: true,
            voice: audio
        )
    }

    private func append(id: String, channel: ZheeChatChannel, senderID: String, senderName: String, text: String, date: Date, isMine: Bool, peerID: String? = nil, voice: Data? = nil) {
        guard !seenIDs.contains(id) else { return }
        seenIDs.insert(id)
        if let voice { voiceData[id] = voice }
        messages.append(ZheeChatMessage(
            id: id, channel: channel.rawValue, senderID: senderID,
            senderName: senderName, text: text,
            timestamp: date.timeIntervalSince1970, isMine: isMine, peerID: peerID,
            hasVoice: voice != nil
        ))
        if messages.count > Self.maxMessages {
            messages.removeFirst(messages.count - Self.maxMessages)
        }
        save()
    }

    // MARK: - Persistence

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZheeChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("messages.json")
    }

    private static func loadMessages() -> [ZheeChatMessage] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ZheeChatMessage].self, from: data) else { return [] }
        return decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(messages) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
