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

    // MARK: - E2EE PIN lock (Messenger-style secure storage)

    /// True while the encrypted history exists but no key is available
    /// (new device / reinstall / wiped Keychain): the user must enter the
    /// PIN before any message is shown. While locked, inbound traffic is
    /// dropped, never stored in the clear.
    @Published private(set) var isLocked = false
    /// True when a PIN protects the history (Keychain holds the derived key).
    @Published private(set) var pinEnabled = false
    /// Derived PIN key, kept in memory only while the session is unlocked.
    private var pinKey: Data?

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
        // Encrypted history (PIN on): auto-unlock only if the Keychain
        // still holds the derived key. Otherwise stay locked until the
        // user enters the PIN — messages are never read in the clear.
        if FileManager.default.fileExists(atPath: Self.encryptedFileURL.path) {
            pinEnabled = true
            if let key = ZheePINVault.loadKey(),
               let blob = try? Data(contentsOf: Self.encryptedFileURL),
               let plain = ZheePINVault.decryptHistory(blob, key: key),
               let decoded = try? JSONDecoder().decode([ZheeChatMessage].self, from: plain) {
                messages = decoded
                pinKey = key
            } else {
                isLocked = true
            }
        } else {
            pinEnabled = ZheePINVault.pinEnabled
            pinKey = ZheePINVault.loadKey()
            messages = Self.loadMessages()
        }
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
        // Emergency wipe takes the PIN lock + encrypted history with it.
        pinEnabled = false
        pinKey = nil
        isLocked = false
        ZheePINVault.deleteAll()
        try? FileManager.default.removeItem(at: Self.encryptedFileURL)
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
        // While PIN-locked, inbound traffic is dropped, never stored in the clear.
        guard !isLocked, !seenIDs.contains(id) else { return }
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

    /// Encrypted history (PIN on): AES-256-CBC of the same JSON.
    private static var encryptedFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZheeChat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("messages.enc")
    }

    private static func loadMessages() -> [ZheeChatMessage] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ZheeChatMessage].self, from: data) else { return [] }
        return decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        if pinEnabled, let key = pinKey {
            if let enc = ZheePINVault.encryptHistory(data, key: key) {
                try? enc.write(to: Self.encryptedFileURL, options: .atomic)
                try? FileManager.default.removeItem(at: Self.fileURL)
            }
        } else if !pinEnabled {
            try? data.write(to: Self.fileURL, options: .atomic)
            try? FileManager.default.removeItem(at: Self.encryptedFileURL)
        }
        // pinEnabled but no key (locked): never write plaintext.
    }

    // MARK: - E2EE PIN: setup / unlock / change / remove / reset

    /// First-time PIN setup. Encrypts the current history in place.
    @discardableResult
    func setupPIN(_ pin: String) -> Bool {
        guard ZheePINVault.isValidPIN(pin), !pinEnabled else { return false }
        let salt = ZheePINVault.randomSalt()
        let key = ZheePINVault.deriveKey(pin: pin, salt: salt)
        ZheePINVault.saveSalt(salt)
        ZheePINVault.saveKey(key)
        pinKey = key
        pinEnabled = true
        isLocked = false
        save()
        return true
    }

    /// Unlock encrypted history with the PIN (new device / reinstall).
    /// Wrong PIN fails the AES padding + JSON decode — nothing is revealed.
    @discardableResult
    func unlock(with pin: String) -> Bool {
        guard isLocked, ZheePINVault.isValidPIN(pin),
              let salt = ZheePINVault.loadSalt() else { return false }
        let key = ZheePINVault.deriveKey(pin: pin, salt: salt)
        guard let blob = try? Data(contentsOf: Self.encryptedFileURL),
              let plain = ZheePINVault.decryptHistory(blob, key: key),
              let decoded = try? JSONDecoder().decode([ZheeChatMessage].self, from: plain) else { return false }
        pinKey = key
        ZheePINVault.saveKey(key)
        messages = decoded
        seenIDs = Set(messages.map { $0.id })
        isLocked = false
        return true
    }

    /// Change PIN: verifies the old PIN against the stored key, then
    /// re-encrypts history under a fresh salt + key.
    @discardableResult
    func changePIN(old: String, new: String) -> Bool {
        guard pinEnabled, ZheePINVault.isValidPIN(old), ZheePINVault.isValidPIN(new),
              let salt = ZheePINVault.loadSalt(),
              let storedKey = ZheePINVault.loadKey(),
              ZheePINVault.deriveKey(pin: old, salt: salt) == storedKey else { return false }
        let newSalt = ZheePINVault.randomSalt()
        let newKey = ZheePINVault.deriveKey(pin: new, salt: newSalt)
        ZheePINVault.saveSalt(newSalt)
        ZheePINVault.saveKey(newKey)
        pinKey = newKey
        save()
        return true
    }

    /// Turn PIN off: verifies the PIN, then writes history back as plaintext.
    @discardableResult
    func removePIN(_ pin: String) -> Bool {
        guard pinEnabled, ZheePINVault.isValidPIN(pin),
              let salt = ZheePINVault.loadSalt(),
              let storedKey = ZheePINVault.loadKey(),
              ZheePINVault.deriveKey(pin: pin, salt: salt) == storedKey else { return false }
        pinEnabled = false
        pinKey = nil
        ZheePINVault.deleteAll()
        save()
        return true
    }

    /// Forgot PIN escape hatch: deletes the encrypted history + PIN key
    /// and starts fresh. The old history is unrecoverable without the PIN,
    /// exactly like Messenger.
    func resetEncryptedHistory() {
        messages.removeAll()
        seenIDs.removeAll()
        currentGeohash = nil
        nostr.setGeoFilter(nil)
        pinEnabled = false
        pinKey = nil
        isLocked = false
        ZheePINVault.deleteAll()
        try? FileManager.default.removeItem(at: Self.encryptedFileURL)
        save()
    }

    // MARK: - E2EE backup: export / import (new device restore)

    private struct BackupPayload: Codable {
        var version: Int
        var identitySecret: Data
        var displayName: String
        var relays: [String]
        var messages: [ZheeChatMessage]
    }

    /// Encrypted backup blob (salt-prefixed) for sharing to a new device.
    /// Needs the session unlocked — the PIN itself is never in the backup.
    func exportBackup() -> Data? {
        guard pinEnabled, let key = pinKey, let salt = ZheePINVault.loadSalt() else { return nil }
        let identity = ZheeNostrIdentity.shared
        let relays = UserDefaults.standard.stringArray(forKey: "zheechat.relays") ?? []
        let payload = BackupPayload(
            version: 1,
            identitySecret: identity.exportSecretData(),
            displayName: identity.displayName,
            relays: relays,
            messages: messages
        )
        guard let json = try? JSONEncoder().encode(payload) else { return nil }
        return ZheePINVault.encryptBackup(json, key: key, salt: salt)
    }

    /// Restore a backup on a new device: decrypts with the PIN, adopts the
    /// backup's salt + key, restores identity + history, reconnects.
    /// Wrong PIN fails the decrypt — returns false, nothing changes.
    @discardableResult
    func importBackup(_ blob: Data, pin: String) -> Bool {
        guard ZheePINVault.isValidPIN(pin),
              let (plain, salt, key) = ZheePINVault.decryptBackup(blob, pin: pin),
              let payload = try? JSONDecoder().decode(BackupPayload.self, from: plain),
              payload.version == 1,
              ZheeNostrIdentity.shared.importSecretData(payload.identitySecret) else { return false }
        ZheePINVault.saveSalt(salt)
        ZheePINVault.saveKey(key)
        pinKey = key
        pinEnabled = true
        isLocked = false
        let identity = ZheeNostrIdentity.shared
        identity.displayName = payload.displayName
        UserDefaults.standard.set(payload.relays, forKey: "zheechat.relays")
        messages = Array(payload.messages.suffix(Self.maxMessages))
        seenIDs = Set(messages.map { $0.id })
        currentGeohash = nil
        nostr.setGeoFilter(nil)
        save()
        mesh.restart()
        if !payload.relays.isEmpty { nostr.updateRelays(payload.relays) }
        return true
    }
}
