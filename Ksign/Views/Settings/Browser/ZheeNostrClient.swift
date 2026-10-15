import CryptoKit
import Foundation

/// Nostr profile metadata (kind 0): {name, picture, about}.
struct ZheeNostrProfile: Codable {
    var name: String?
    var picture: String?
    var about: String?
}

/// A Nostr event (NIP-01) on the public ZheeChat channel.
struct ZheeNostrEvent: Identifiable {
    let id: String // hex event id
    let pubkey: String // hex
    let createdAt: TimeInterval
    let kind: Int
    let tags: [[String]]
    let content: String
    let sig: String // hex Schnorr signature

    var date: Date { Date(timeIntervalSince1970: createdAt) }
}

/// Minimal Nostr client (NIP-01) over URLSessionWebSocket.
/// Connects to public relays, subscribes to kind-1 notes tagged #zheechat,
/// and publishes signed notes to the same channel. Every inbound event is
/// verified: its id must match the recomputed hash and its Schnorr signature
/// must verify against its pubkey.
final class ZheeNostrClient: ObservableObject {
    static let channelTag = "zheechat"
    static let defaultRelays = [
        "wss://relay.damus.io",
        "wss://nos.lol",
        "wss://relay.nostr.band"
    ]
    private static let relaysKey = "zheechat.relays"
    private static let subscriptionID = "zheechat-1"
    private static let dmSubscriptionID = "zheechat-dm-1"
    private static let geoSubscriptionID = "zheechat-geo-1"

    /// Active geohash filter, if the user enabled the nearby channel.
    private(set) var currentGeo: String?

    @Published private(set) var connectedRelayURLs: Set<String> = []
    @Published private(set) var relayCount = 0

    var onEvent: ((ZheeNostrEvent) -> Void)?
    /// Fires for an inbound kind-4 DM with its decrypted plaintext.
    var onDM: ((ZheeNostrEvent, String) -> Void)?

    /// Nostr profile metadata (kind 0) by pubkey hex.
    @Published private(set) var profiles: [String: ZheeNostrProfile] = [:]
    private var requestedProfiles = Set<String>()
    private static let profilesKey = "zheechat.profiles"

    private var tasks: [String: URLSessionWebSocketTask] = [:]
    private var shouldRun = false
    private var reconnectWork: [String: DispatchWorkItem] = [:]
    private let queue = DispatchQueue(label: "vn.zheedev.zheesign.nostr")
    private lazy var session = URLSession(configuration: .default)

    var relays: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.relaysKey),
                  let list = try? JSONDecoder().decode([String].self, from: data),
                  !list.isEmpty else { return Self.defaultRelays }
            return list
        }
        set {
            let clean = newValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.hasPrefix("wss://") }
            if let data = try? JSONEncoder().encode(clean) {
                UserDefaults.standard.set(data, forKey: Self.relaysKey)
            }
        }
    }

    func start() {
        queue.async { [weak self] in
            guard let self, !shouldRun else { return }
            shouldRun = true
            if let data = UserDefaults.standard.data(forKey: Self.profilesKey),
               let cached = try? JSONDecoder().decode([String: ZheeNostrProfile].self, from: data) {
                DispatchQueue.main.async { self.profiles = cached }
            }
            for url in relays { connect(url) }
            DispatchQueue.main.async { self.relayCount = self.relays.count }
        }
    }

    /// Fetches a pubkey's kind-0 profile (name/picture), once per pubkey.
    func requestProfile(pubkey: String) {
        guard !requestedProfiles.contains(pubkey), profiles[pubkey] == nil else { return }
        requestedProfiles.insert(pubkey)
        let sub = "zheechat-profile-\(String(pubkey.prefix(8)))"
        let req = "[\"REQ\",\"\(sub)\",{\"kinds\":[0],\"authors\":[\"\(pubkey)\"],\"limit\":1}]"
        queue.async { [weak self] in
            guard let self else { return }
            for (_, task) in tasks {
                task.send(.string(req)) { _ in }
            }
        }
    }

    private func handleProfile(_ event: ZheeNostrEvent) {
        guard let data = event.content.data(using: .utf8),
              let profile = try? JSONDecoder().decode(ZheeNostrProfile.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            profiles[event.pubkey] = profile
            if let encoded = try? JSONEncoder().encode(profiles) {
                UserDefaults.standard.set(encoded, forKey: Self.profilesKey)
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            shouldRun = false
            for (_, work) in reconnectWork { work.cancel() }
            reconnectWork.removeAll()
            for (_, task) in tasks { task.cancel(with: .goingAway, reason: nil) }
            tasks.removeAll()
            DispatchQueue.main.async { self.connectedRelayURLs = [] }
        }
    }

    func updateRelays(_ urls: [String]) {
        relays = urls
        stop()
        start()
    }

    /// Builds, signs and broadcasts a channel message. Returns the event so
    /// the caller can echo it locally; nil if signing failed.
    @discardableResult
    func publish(text: String) -> ZheeNostrEvent? {
        let identity = ZheeNostrIdentity.shared
        let createdAt = Int(Date().timeIntervalSince1970)
        let tags = [["t", Self.channelTag]]
        let serialized = Self.serializeForID(
            pubkey: identity.publicKeyHex, createdAt: createdAt, kind: 1,
            tags: tags, content: text
        )
        let idData = Data(SHA256.hash(data: serialized))
        let idHex = idData.map { String(format: "%02x", $0) }.joined()
        guard let sig = ZheeSecp256k1.sign(secret: identity.secret, message: idData) else { return nil }
        let sigHex = sig.map { String(format: "%02x", $0) }.joined()
        let event = ZheeNostrEvent(
            id: idHex, pubkey: identity.publicKeyHex,
            createdAt: TimeInterval(createdAt), kind: 1, tags: tags,
            content: text, sig: sigHex
        )
        let message = "[\"EVENT\",\(Self.eventJSON(event))]"
        queue.async { [weak self] in
            guard let self else { return }
            for (_, task) in tasks {
                task.send(.string(message)) { _ in }
            }
        }
        return event
    }

    /// Builds, signs and broadcasts an encrypted DM (NIP-04, kind 4).
    /// Returns the event so the caller can echo it locally.
    @discardableResult
    func publishDM(text: String, toPubkeyHex: String) -> ZheeNostrEvent? {
        let identity = ZheeNostrIdentity.shared
        guard let encrypted = ZheeNostrDM.encrypt(
            senderSecret: identity.secret, receiverPubkeyHex: toPubkeyHex, plaintext: text
        ) else { return nil }
        let createdAt = Int(Date().timeIntervalSince1970)
        let tags = [["p", toPubkeyHex]]
        let serialized = Self.serializeForID(
            pubkey: identity.publicKeyHex, createdAt: createdAt, kind: 4,
            tags: tags, content: encrypted
        )
        let idData = Data(SHA256.hash(data: serialized))
        let idHex = idData.map { String(format: "%02x", $0) }.joined()
        guard let sig = ZheeSecp256k1.sign(secret: identity.secret, message: idData) else { return nil }
        let sigHex = sig.map { String(format: "%02x", $0) }.joined()
        let event = ZheeNostrEvent(
            id: idHex, pubkey: identity.publicKeyHex,
            createdAt: TimeInterval(createdAt), kind: 4, tags: tags,
            content: encrypted, sig: sigHex
        )
        let message = "[\"EVENT\",\(Self.eventJSON(event))]"
        queue.async { [weak self] in
            guard let self else { return }
            for (_, task) in tasks {
                task.send(.string(message)) { _ in }
            }
        }
        return event
    }

    /// Switches the nearby (geohash) subscription. Nil turns it off.
    func setGeoFilter(_ geohash: String?) {
        let old = currentGeo
        currentGeo = geohash
        queue.async { [weak self] in
            guard let self else { return }
            for (_, task) in tasks {
                if old != nil {
                    task.send(.string("[\"CLOSE\",\"\(Self.geoSubscriptionID)\"]")) { _ in }
                }
                if let geo = geohash {
                    task.send(.string(geoReq(geohash: geo))) { _ in }
                }
            }
        }
    }

    private func geoReq(geohash: String) -> String {
        let since = Int(Date().timeIntervalSince1970) - 24 * 3600
        return "[\"REQ\",\"\(Self.geoSubscriptionID)\",{\"kinds\":[1],\"#t\":[\"\(Self.channelTag)\"],\"#g\":[\"\(geohash)\"],\"limit\":200,\"since\":\(since)}]"
    }

    /// Publishes a message to the nearby (geohash) channel.
    @discardableResult
    func publishGeo(text: String, geohash: String) -> ZheeNostrEvent? {
        let identity = ZheeNostrIdentity.shared
        let createdAt = Int(Date().timeIntervalSince1970)
        let tags = [["t", Self.channelTag], ["g", geohash]]
        let serialized = Self.serializeForID(
            pubkey: identity.publicKeyHex, createdAt: createdAt, kind: 1,
            tags: tags, content: text
        )
        let idData = Data(SHA256.hash(data: serialized))
        let idHex = idData.map { String(format: "%02x", $0) }.joined()
        guard let sig = ZheeSecp256k1.sign(secret: identity.secret, message: idData) else { return nil }
        let sigHex = sig.map { String(format: "%02x", $0) }.joined()
        let event = ZheeNostrEvent(
            id: idHex, pubkey: identity.publicKeyHex,
            createdAt: TimeInterval(createdAt), kind: 1, tags: tags,
            content: text, sig: sigHex
        )
        let message = "[\"EVENT\",\(Self.eventJSON(event))]"
        queue.async { [weak self] in
            guard let self else { return }
            for (_, task) in tasks {
                task.send(.string(message)) { _ in }
            }
        }
        return event
    }

    // MARK: - Connection

    private func connect(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        tasks[urlString]?.cancel(with: .goingAway, reason: nil)
        tasks.removeValue(forKey: urlString)
        reconnectWork[urlString]?.cancel()
        reconnectWork.removeValue(forKey: urlString)
        let task = session.webSocketTask(with: url)
        tasks[urlString] = task
        task.resume()
        let since = Int(Date().timeIntervalSince1970) - 24 * 3600
        let req = "[\"REQ\",\"\(Self.subscriptionID)\",{\"kinds\":[1],\"#t\":[\"\(Self.channelTag)\"],\"limit\":200,\"since\":\(since)}]"
        // DMs addressed to me (NIP-04, kind 4).
        let dmReq = "[\"REQ\",\"\(Self.dmSubscriptionID)\",{\"kinds\":[4],\"#p\":[\"\(ZheeNostrIdentity.shared.publicKeyHex)\"],\"limit\":200,\"since\":\(since)}]"
        task.send(.string(req)) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.connectedRelayURLs.insert(urlString)
                }
            }
        }
        task.send(.string(dmReq)) { _ in }
        if let geo = currentGeo {
            task.send(.string(geoReq(geohash: geo))) { _ in }
        }
        receiveNext(task, urlString)
    }

    private func receiveNext(_ task: URLSessionWebSocketTask, _ urlString: String) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handleMessage(text)
                }
                self.queue.async { self.receiveNext(task, urlString) }
            case .failure:
                self.queue.async { self.handleDisconnect(urlString) }
            }
        }
    }

    private func handleDisconnect(_ urlString: String) {
        tasks.removeValue(forKey: urlString)
        DispatchQueue.main.async { self.connectedRelayURLs.remove(urlString) }
        guard shouldRun else { return }
        reconnectWork[urlString]?.cancel()
        reconnectWork.removeValue(forKey: urlString)
        let work = DispatchWorkItem { [weak self] in
            guard let self, shouldRun else { return }
            self.connect(urlString)
        }
        reconnectWork[urlString] = work
        queue.asyncAfter(deadline: .now() + 5, execute: work)
    }

    // MARK: - Messages

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let type = json.first as? String, type == "EVENT",
              json.count >= 3,
              let dict = json[2] as? [String: Any],
              let event = Self.parseEvent(dict),
              Self.verify(event) else { return }
        if event.kind == 0 {
            handleProfile(event)
        } else if event.kind == 4 {
            // Decrypt the DM; drop it silently if it is not for us / undecryptable.
            let identity = ZheeNostrIdentity.shared
            guard let plaintext = ZheeNostrDM.decrypt(
                receiverSecret: identity.secret, senderPubkeyHex: event.pubkey,
                encrypted: event.content
            ) else { return }
            DispatchQueue.main.async { self.onDM?(event, plaintext) }
        } else if event.kind == 1 {
            DispatchQueue.main.async { self.onEvent?(event) }
        }
    }

    static func parseEvent(_ dict: [String: Any]) -> ZheeNostrEvent? {
        guard let id = dict["id"] as? String,
              let pubkey = dict["pubkey"] as? String,
              let createdAt = dict["created_at"] as? Int,
              let kind = dict["kind"] as? Int,
              let tags = dict["tags"] as? [[String]],
              let content = dict["content"] as? String,
              let sig = dict["sig"] as? String else { return nil }
        return ZheeNostrEvent(
            id: id, pubkey: pubkey, createdAt: TimeInterval(createdAt),
            kind: kind, tags: tags, content: content, sig: sig
        )
    }

    /// Recomputes the event id and verifies the Schnorr signature.
    static func verify(_ event: ZheeNostrEvent) -> Bool {
        let serialized = serializeForID(
            pubkey: event.pubkey, createdAt: Int(event.createdAt),
            kind: event.kind, tags: event.tags, content: event.content
        )
        let idData = Data(SHA256.hash(data: serialized))
        guard idData.map({ String(format: "%02x", $0) }).joined() == event.id,
              let pub = Data(hex: event.pubkey),
              let sig = Data(hex: event.sig) else { return false }
        return ZheeSecp256k1.verify(publicKey: pub, message: idData, signature: sig)
    }

    /// NIP-01 serialization for the event id: [0, pubkey, created_at, kind, tags, content].
    static func serializeForID(pubkey: String, createdAt: Int, kind: Int, tags: [[String]], content: String) -> Data {
        let tagsJSON = "[" + tags.map { tag in
            "[" + tag.map { "\"\(jsonEscape($0))\"" }.joined(separator: ",") + "]"
        }.joined(separator: ",") + "]"
        let json = "[0,\"\(pubkey)\",\(createdAt),\(kind),\(tagsJSON),\"\(jsonEscape(content))\"]"
        return Data(json.utf8)
    }

    static func eventJSON(_ event: ZheeNostrEvent) -> String {
        let tagsJSON = "[" + event.tags.map { tag in
            "[" + tag.map { "\"\(jsonEscape($0))\"" }.joined(separator: ",") + "]"
        }.joined(separator: ",") + "]"
        return "{\"id\":\"\(event.id)\",\"pubkey\":\"\(event.pubkey)\",\"created_at\":\(Int(event.createdAt)),\"kind\":\(event.kind),\"tags\":\(tagsJSON),\"content\":\"\(jsonEscape(event.content))\",\"sig\":\"\(event.sig)\"}"
    }

    static func jsonEscape(_ string: String) -> String {
        var out = ""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.append(Character(scalar))
                }
            }
        }
        return out
    }
}

extension Data {
    /// Parses a lowercase/uppercase hex string into bytes.
    init?(hex: String) {
        guard hex.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
