import AVFoundation
import CoreLocation
import SwiftUI
import UIKit

/// ZheeChat — chat phi tập trung trong ZheeSign.
/// Mesh gần: chat offline với thiết bị gần bạn (Bluetooth + Wi-Fi cục bộ).
/// Nostr công khai: chat toàn cầu qua relay, ký bằng Schnorr.
struct ZheeChatView: View {
    @StateObject private var store = ZheeChatStore.shared
    @StateObject private var identity = ZheeNostrIdentity.shared
    @State private var channel: ZheeChatChannel = .mesh
    @State private var draft = ""
    @State private var showIdentity = false
    @State private var selectedPeer: String?
    @State private var showNewDM = false
    @StateObject private var location = ZheeLocationProvider()
    @State private var showWipeConfirm = false
    @StateObject private var recorder = ZheeVoiceRecorder()

    /// Opens straight into a channel (from the recent-chats list), or
    /// straight into a DM thread when `peer` is set.
    init(channel: ZheeChatChannel = .mesh, peer: String? = nil) {
        _channel = State(initialValue: channel)
        _selectedPeer = State(initialValue: peer)
    }

    private var messages: [ZheeChatMessage] {
        store.messages(in: channel)
    }

    /// Marks the conversation currently on screen as read.
    private func markCurrentRead() {
        if channel == .dm {
            if let peer = selectedPeer { store.markRead("dm:\(peer)") }
        } else {
            store.markRead(channel.rawValue)
        }
    }

    var body: some View {
        // Khong con chip picker: chuyen kenh o danh sach Doan chat.
        VStack(spacing: 0) {
            if channel == .dm {
                dmBody
            } else if channel == .geo && store.currentGeohash == nil {
                geoEmptyState
            } else {
                statusLine
                Divider()
                messageList
                composer
            }
        }
        // Luon neo len tren.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: selectedPeer) { _ in markCurrentRead() }
        .onChange(of: location.coordinate.map { "\($0.latitude),\($0.longitude)" }) { _ in
            if let coord = location.coordinate {
                store.setGeohash(ZheeGeohash.encode(latitude: coord.latitude, longitude: coord.longitude, precision: 5))
            }
        }
        .onChange(of: store.pendingShareText) { _ in
            if let text = store.pendingShareText {
                draft = text
                store.pendingShareText = nil
            }
        }
        .onAppear {
            markCurrentRead()
            if let text = store.pendingShareText {
                draft = text
                store.pendingShareText = nil
            }
        }
        .navigationTitle("ZheeChat")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if store.isLocked {
                ZheePINLockView()
            }
        }
        .toolbar {
            // Panic gesture: triple-tap the title (khong dat tren picker nua,
            // vi triple-tap tren cha lam nut chip bi delay).
            ToolbarItem(placement: .principal) {
                Text("ZheeChat")
                    .font(.headline)
                    .onTapGesture(count: 3) {
                        showWipeConfirm = true
                    }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showIdentity = true
                } label: {
                    ZheeChatRowAvatar(urlString: store.profiles[identity.publicKeyHex]?.picture, name: identity.displayName, size: 30)
                }
            }
        }
        .sheet(isPresented: $showIdentity) {
            ZheeChatIdentityView()
        }
        .onAppear {
            store.start()
            recorder.onFinish = { data in
                if let data, !data.isEmpty {
                    store.sendVoice(data)
                }
            }
        }
        .confirmationDialog("Emergency Wipe?", isPresented: $showWipeConfirm) {
            Button("Xóa tất cả — định danh + lịch sử", role: .destructive) {
                ZheeNostrIdentity.shared.wipe()
                store.wipeAll()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Xóa vĩnh viễn định danh (npub/nsec), tên hiển thị và toàn bộ lịch sử chat. Không khôi phục được nếu chưa sao lưu nsec.")
        }
    }

    private var dmBody: some View {
        Group {
            if let peer = selectedPeer {
                ZheeDMThreadView(peer: peer) { selectedPeer = nil }
            } else {
                dmList
            }
        }
        .sheet(isPresented: $showNewDM) {
            ZheeNewDMView { peer in
                showNewDM = false
                selectedPeer = peer
            }
        }
    }

    private var dmList: some View {
        List {
            Section {
                Button {
                    showNewDM = true
                } label: {
                    Label("Nhắn tin mới", systemImage: "square.and.pencil")
                }
            }
            if store.dmConversations.isEmpty {
                Text("Chưa có DM nào. Nhắn tin mới bằng npub của người nhận — tin nhắn được mã hóa NIP-04, chỉ 2 người đọc được.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(store.dmConversations, id: \.peer) { conv in
                    Button {
                        selectedPeer = conv.peer
                    } label: {
                        HStack {
                            Image(systemName: "lock").font(.system(size: 12)).foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("npub1" + String(conv.peer.prefix(8)))
                                    .font(.subheadline.bold())
                                Text(conv.lastMessage.text)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(timeText(conv.lastMessage.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.clearDM(peer: conv.peer)
                        } label: {
                            Label("Xóa", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var geoEmptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.12))
                Image(systemName: "mappin").font(.system(size: 40)).foregroundColor(.blue)
            }
            .frame(width: 88, height: 88)
            Text("Kênh gần tôi")
                .font(.headline)
            Text("Kênh gần tôi cần vị trí của bạn.\nChỉ dùng ô geohash ~5km, không gửi tọa độ chính xác.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Bật vị trí") {
                location.request()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal)
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(channel == .mesh ? Color.green : (store.nostrConnected ? Color.green : Color.orange))
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private var statusText: String {
        switch channel {
        case .mesh:
            if store.meshPeerCount == 0 {
                return "Đang tìm thiết bị gần bạn…"
            }
            return "\(store.meshPeerCount) thiết bị gần bạn"
        case .nostr:
            if store.nostrConnected {
                return "Đã kết nối \(store.nostrRelayCount) relay"
            }
            return "Đang kết nối relay…"
        case .dm:
            return store.nostrConnected ? "Đã kết nối \(store.nostrRelayCount) relay" : "Đang kết nối relay…"
        case .geo:
            if let geo = store.currentGeohash {
                return "Kênh #\(geo) · ~5km"
            }
            return "Chưa có vị trí"
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: store.messages.count) { _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.gray.opacity(0.12))
                Image(systemName: channel == .mesh ? "wifi" : "globe").font(.system(size: 40)).foregroundColor(.secondary)
            }
            .frame(width: 88, height: 88)
            Text(channel == .mesh
                 ? "Chưa có tin nhắn nào.\nMở ZheeChat trên 2 máy gần nhau để chat offline."
                 : "Chưa có tin nhắn nào.\nKênh công khai — ai dùng ZheeChat cũng thấy.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func messageRow(_ message: ZheeChatMessage) -> some View {
        HStack {
            if message.isMine { Spacer(minLength: 48) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                if !message.isMine {
                    HStack(spacing: 5) {
                        ZheeAvatarView(urlString: store.profiles[message.senderID]?.picture, name: message.senderName)
                        Text(message.senderName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                if message.hasVoice {
                    ZheeVoiceBubble(audio: store.voiceData(for: message.id), isMine: message.isMine, seed: message.id)
                } else {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(message.isMine ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(message.isMine ? Color.blue : Color(.secondarySystemBackground))
                        )
                }
                Text(timeText(message.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !message.isMine { Spacer(minLength: 48) }
        }
    }

    private var composer: some View {
        Group {
            if recorder.isRecording || recorder.isPaused {
                recordingBar
            } else {
                HStack(spacing: 8) {
                    TextField("Nhắn tin…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit { send() }
                    if channel == .mesh {
                        Button { recorder.start() } label: {
                            Image(systemName: "mic").font(.system(size: 18))
                                .padding(10)
                                .background(Circle().fill(Color.gray.opacity(0.25)))
                                .foregroundColor(.primary)
                        }
                    }
                    Button(action: send) {
                        Image(systemName: "paperplane.fill").font(.system(size: 18)).foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(canSend ? Color.blue : Color.gray.opacity(0.4)))
                            .foregroundColor(.white)
                    }
                    .disabled(!canSend)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    /// Messenger-style recording bar: trash (cancel) | pill with
    /// pause/resume + live waveform + timer | send arrow.
    private var recordingBar: some View {
        HStack(spacing: 12) {
            Button { recorder.cancel() } label: {
                Image(systemName: "trash").font(.system(size: 20)).foregroundColor(ZheeVoiceStyle.teal)
            }
            HStack(spacing: 8) {
                Button {
                    if recorder.isPaused { recorder.resume() } else { recorder.pause() }
                } label: {
                    Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill").font(.system(size: 12)).foregroundColor(ZheeVoiceStyle.teal)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white))
                }
                HStack(spacing: 2.5) {
                    ForEach(0..<24, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.25)
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 2.5, height: recordingBarHeight(i))
                    }
                }
                Text(ZheeVoiceStyle.mmss(recorder.elapsed))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(ZheeVoiceStyle.teal))
            Button { recorder.finish() } label: {
                Image(systemName: "paperplane.fill").font(.system(size: 20)).foregroundColor(ZheeVoiceStyle.teal)
            }
        }
    }

    private func recordingBarHeight(_ i: Int) -> CGFloat {
        let tail = Array(recorder.levels.suffix(24))
        let pad = max(0, 24 - tail.count)
        if i < pad { return 5 }
        return 4 + tail[i - pad] * 18
    }

    private var canSend: Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        if channel == .nostr && !store.nostrConnected { return false }
        if channel == .geo && (store.currentGeohash == nil || !store.nostrConnected) { return false }
        return true
    }

    private func send() {
        guard canSend else { return }
        store.send(text: draft, channel: channel)
        draft = ""
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

/// One encrypted DM thread.
private struct ZheeDMThreadView: View {
    @StateObject private var store = ZheeChatStore.shared
    let peer: String
    let onBack: () -> Void
    @State private var draft = ""

    private var messages: [ZheeChatMessage] { store.dmMessages(peer: peer) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16))
                }
                Image(systemName: "lock").font(.system(size: 12)).foregroundColor(.green)
                Text("npub1" + String(peer.prefix(8)))
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text(store.nostrConnected ? "Đã kết nối" : "Đang kết nối…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: store.messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Nhắn tin riêng…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit { send() }
                Button(action: send) {
                    Image(systemName: "paperplane.fill").font(.system(size: 18)).foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(canSend ? Color.blue : Color.gray.opacity(0.4)))
                        .foregroundColor(.white)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.nostrConnected
    }

    private func send() {
        guard canSend else { return }
        store.sendDM(text: draft, toPeer: peer)
        draft = ""
    }

    private func messageRow(_ message: ZheeChatMessage) -> some View {
        HStack {
            if message.isMine { Spacer(minLength: 48) }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(message.isMine ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isMine ? Color.blue : Color(.secondarySystemBackground))
                    )
                Text(timeText(message.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !message.isMine { Spacer(minLength: 48) }
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

/// New DM: enter the recipient's npub (or 64-char hex pubkey).
struct ZheeNewDMView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var error = ""
    let onSelect: (String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Người nhận") {
                    TextField("npub1… hoặc 64 ký tự hex", text: $input)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    if !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                Section {
                    Button("Bắt đầu nhắn") {
                        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let hex = ZheeBech32.decodeNpub(text)?.map({ String(format: "%02x", $0) }).joined() {
                            onSelect(hex)
                        } else if text.count == 64, Data(hex: text) != nil {
                            onSelect(text.lowercased())
                        } else {
                            error = "npub hoặc pubkey hex không hợp lệ"
                        }
                    }
                }
                Section {
                    Text("DM được mã hóa NIP-04: chỉ bạn và người nhận đọc được. Relay chỉ thấy bản mã.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("DM mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Hủy") { dismiss() }
                }
            }
        }
    }
}

/// Small profile avatar: picture URL if available, else initial letter.
private struct ZheeAvatarView: View {
    let urlString: String?
    let name: String

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initialCircle
                    }
                }
            } else {
                initialCircle
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(Circle())
    }

    private var initialCircle: some View {
        ZStack {
            Circle().fill(Color.gray.opacity(0.3))
            Text(String(name.prefix(1)).uppercased())
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
    }
}

/// Messenger-style voice bubble: dark play circle + waveform + duration.
private struct ZheeVoiceBubble: View {
    @StateObject private var player = ZheeVoicePlayer()
    @State private var duration: TimeInterval?
    let audio: Data?
    let isMine: Bool
    let seed: String

    private var barColor: Color { isMine ? Color.white.opacity(0.95) : ZheeVoiceStyle.teal }

    private func barHeight(_ i: Int) -> CGFloat {
        let base = seed.utf8.reduce(0) { $0 &+ Int($1) }
        return 5 + 11 * abs(sin(Double(i) * 1.7 + Double(base) * 0.13))
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if let audio { player.play(audio) }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 12)).foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(ZheeVoiceStyle.darkTeal))
            }
            .disabled(audio == nil)
            HStack(spacing: 2.5) {
                ForEach(0..<20, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.25)
                        .fill(barColor)
                        .frame(width: 2.5, height: barHeight(i))
                }
            }
            if let duration {
                Text(ZheeVoiceStyle.mmss(duration))
                    .font(.caption)
                    .foregroundColor(isMine ? .white : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isMine ? ZheeVoiceStyle.teal : Color(.secondarySystemBackground))
        )
        .onAppear {
            if duration == nil, let audio {
                duration = (try? AVAudioPlayer(data: audio))?.duration
            }
        }
    }
}

/// Shared Messenger-style voice colors + duration format.
private enum ZheeVoiceStyle {
    static let teal = Color(red: 0.31, green: 0.64, blue: 0.56)
    static let darkTeal = Color(red: 0.13, green: 0.32, blue: 0.29)

    static func mmss(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// One-shot location provider for the nearby (geohash) channel.
private final class ZheeLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            coordinate = loc.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// Identity sheet: display name, npub/nsec backup, relay list, import/rotate.
struct ZheeChatIdentityView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var identity = ZheeNostrIdentity.shared
    @State private var relaysText = ""
    @State private var importText = ""
    @State private var notice = ""
    @State private var showRotateConfirm = false
    @State private var showClearConfirm = false
    @State private var showWipeConfirm = false
    @State private var initialDisplayName = ""
    @State private var pinMode: ZheePINMode?
    @State private var showImporter = false
    @State private var importData: Data?
    @State private var showResetConfirm = false
    @State private var showExporter = false
    @State private var backupURL: URL?

    var body: some View {
        NavigationView {
            Form {
                Section("Tên hiển thị") {
                    TextField("Tên hiển thị", text: $identity.displayName)
                        .autocorrectionDisabled()
                }
                Section("Định danh Nostr") {
                    HStack {
                        Text("npub")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(identity.npub)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = identity.npub
                            notice = "Đã copy npub"
                        }
                        .font(.caption)
                    }
                    HStack {
                        Text("nsec")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("••••••••••••")
                            .font(.caption.monospaced())
                        Spacer()
                        Button("Copy") {
                            UIPasteboard.general.string = identity.nsec
                            notice = "Đã copy nsec — giữ kín, ai có nó là giả mạo được bạn"
                        }
                        .font(.caption)
                    }
                    Text("nsec là khóa bí mật. Đừng gửi cho ai.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                Section("Nhập định danh (nsec)") {
                    TextField("nsec1…", text: $importText)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    Button("Nhập") {
                        if identity.importNsec(importText) {
                            notice = "Đã nhập định danh mới"
                            importText = ""
                            ZheeChatStore.shared.mesh.restart()
                        } else {
                            notice = "nsec không hợp lệ"
                        }
                    }
                }
                Section("Relay Nostr (mỗi dòng 1 relay)") {
                    TextEditor(text: $relaysText)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .frame(minHeight: 90)
                        .font(.caption.monospaced())
                    Button("Lưu relay") {
                        let urls = relaysText.split(separator: "\n").map { String($0) }
                        ZheeChatStore.shared.nostr.updateRelays(urls)
                        notice = "Đã lưu relay"
                    }
                }
                Section("Mã hóa đầu cuối (mã PIN)") {
                    HStack {
                        Image(systemName: "lock").font(.system(size: 14)).foregroundColor(ZheeChatStore.shared.pinEnabled ? .green : .secondary)
                        Text(ZheeChatStore.shared.pinEnabled
                             ? "Đang bật — tin nhắn lưu mã hóa, cần mã PIN để khôi phục trên máy mới"
                             : "Chưa bật — tin nhắn lưu dạng thường")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if ZheeChatStore.shared.pinEnabled {
                        Button("Đổi mã PIN") { pinMode = .change }
                        Button("Tắt mã PIN") { pinMode = .remove }
                        Button("Sao lưu tin nhắn mã hóa") {
                            if let blob = ZheeChatStore.shared.exportBackup() {
                                let url = FileManager.default.temporaryDirectory
                                    .appendingPathComponent("ZheeChat-Backup.zheechat")
                                try? blob.write(to: url)
                                backupURL = url
                                showExporter = true
                            } else {
                                notice = "Chưa sao lưu được — thử lại"
                            }
                        }
                        Button("Khôi phục tin nhắn (máy mới)") { showImporter = true }
                    } else {
                        Button("Đặt mã PIN") { pinMode = .setup }
                        Button("Khôi phục tin nhắn (máy mới)") { showImporter = true }
                    }
                }
                Section {
                    Button("Đổi định danh mới", role: .destructive) {
                        showRotateConfirm = true
                    }
                    Button("Xóa lịch sử chat", role: .destructive) {
                        showClearConfirm = true
                    }
                    Button("Emergency Wipe (xóa tất cả)", role: .destructive) {
                        showWipeConfirm = true
                    }
                }
                if !notice.isEmpty {
                    Text(notice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Định danh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                }
            }
            .onAppear {
                relaysText = ZheeChatStore.shared.nostr.relays.joined(separator: "\n")
                initialDisplayName = identity.displayName
            }
            .onDisappear {
                // Peer name is baked into the mesh identity: restart if renamed.
                if identity.displayName != initialDisplayName {
                    ZheeChatStore.shared.mesh.restart()
                }
            }
            .confirmationDialog("Đổi định danh mới?", isPresented: $showRotateConfirm) {
                Button("Đổi (không khôi phục được)", role: .destructive) {
                    identity.rotate()
                    ZheeChatStore.shared.mesh.restart()
                    notice = "Đã đổi định danh mới — nhớ sao lưu nsec"
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Định danh cũ mất vĩnh viễn nếu chưa sao lưu nsec.")
            }
            .confirmationDialog("Xóa toàn bộ lịch sử chat?", isPresented: $showClearConfirm) {
                Button("Xóa", role: .destructive) {
                    ZheeChatStore.shared.clear(channel: .mesh)
                    ZheeChatStore.shared.clear(channel: .nostr)
                    ZheeChatStore.shared.clear(channel: .dm)
                    ZheeChatStore.shared.clear(channel: .geo)
                    notice = "Đã xóa lịch sử"
                }
                Button("Hủy", role: .cancel) {}
            }
            .confirmationDialog("Emergency Wipe?", isPresented: $showWipeConfirm) {
                Button("Xóa tất cả — định danh + lịch sử", role: .destructive) {
                    ZheeNostrIdentity.shared.wipe()
                    ZheeChatStore.shared.wipeAll()
                    notice = "Đã wipe: định danh mới đã được tạo"
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Xóa vĩnh viễn định danh (npub/nsec), tên hiển thị và toàn bộ lịch sử chat. Không khôi phục được nếu chưa sao lưu nsec.")
            }
            .sheet(item: $pinMode) { mode in
                ZheePINFormView(mode: mode, importData: importData) { result in
                    notice = result
                    pinMode = nil
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data]) { result in
                if case .success(let url) = result,
                   url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    importData = try? Data(contentsOf: url)
                    if importData != nil {
                        pinMode = .importBackup
                    } else {
                        notice = "Không đọc được file sao lưu"
                    }
                }
            }
            .sheet(isPresented: $showExporter) {
                if let url = backupURL {
                    ShareLink(item: url) {
                        Label("Chia sẻ file sao lưu", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

/// PIN form modes for the E2EE vault.
enum ZheePINMode: Identifiable {
    case setup, change, remove, importBackup
    var id: Self { self }

    var title: String {
        switch self {
        case .setup: return "Đặt mã PIN"
        case .change: return "Đổi mã PIN"
        case .remove: return "Tắt mã PIN"
        case .importBackup: return "Khôi phục tin nhắn"
        }
    }
}

/// One form for every PIN operation: setup (new + confirm), change
/// (old + new + confirm), remove (current), import backup (backup PIN).
/// PBKDF2 runs synchronously (~0.2s) with a spinner while it derives.
private struct ZheePINFormView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: ZheePINMode
    let importData: Data?
    let onDone: (String) -> Void

    @State private var current = ""
    @State private var newPIN = ""
    @State private var confirm = ""
    @State private var error = ""
    @State private var busy = false

    private var canSubmit: Bool {
        switch mode {
        case .setup:
            return ZheePINVault.isValidPIN(newPIN) && newPIN == confirm
        case .change:
            return ZheePINVault.isValidPIN(current) && ZheePINVault.isValidPIN(newPIN) && newPIN == confirm
        case .remove, .importBackup:
            return ZheePINVault.isValidPIN(current)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(pinHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if mode == .change || mode == .remove {
                    Section("Mã PIN hiện tại") {
                        SecureField("Mã PIN hiện tại", text: $current)
                            .keyboardType(.numberPad)
                    }
                }
                if mode == .setup || mode == .change {
                    Section("Mã PIN mới") {
                        SecureField("Mã PIN mới (6 số)", text: $newPIN)
                            .keyboardType(.numberPad)
                        SecureField("Nhập lại mã PIN mới", text: $confirm)
                            .keyboardType(.numberPad)
                    }
                }
                if mode == .importBackup {
                    Section("Mã PIN của bản sao lưu") {
                        SecureField("Mã PIN (6 số)", text: $current)
                            .keyboardType(.numberPad)
                    }
                }
                if !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Section {
                    Button {
                        submit()
                    } label: {
                        if busy {
                            HStack { ProgressView(); Text("Đang xử lý…") }
                        } else {
                            Text(mode.title)
                        }
                    }
                    .disabled(!canSubmit || busy)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Hủy") { dismiss() }
                }
            }
        }
    }

    private var pinHint: String {
        switch mode {
        case .setup:
            return "Mã PIN 6 số mã hóa toàn bộ lịch sử chat. Quên mã PIN thì không khôi phục được — hãy nhớ kỹ hoặc ghi ra giấy."
        case .change:
            return "Đổi mã PIN sẽ mã hóa lại toàn bộ lịch sử bằng mã mới."
        case .remove:
            return "Tắt mã PIN sẽ lưu lịch sử về dạng thường (không mã hóa)."
        case .importBackup:
            return "Nhập mã PIN của bản sao lưu để giải mã và khôi phục tin nhắn + định danh trên máy này."
        }
    }

    private func submit() {
        busy = true
        defer { busy = false }
        let store = ZheeChatStore.shared
        switch mode {
        case .setup:
            if store.setupPIN(newPIN) {
                onDone("Đã bật mã hóa đầu cuối bằng mã PIN")
                dismiss()
            } else {
                error = "Không đặt được mã PIN"
            }
        case .change:
            if store.changePIN(old: current, new: newPIN) {
                onDone("Đã đổi mã PIN")
                dismiss()
            } else {
                error = "Mã PIN hiện tại không đúng"
            }
        case .remove:
            if store.removePIN(current) {
                onDone("Đã tắt mã PIN — lịch sử lưu dạng thường")
                dismiss()
            } else {
                error = "Mã PIN không đúng"
            }
        case .importBackup:
            if let data = importData, store.importBackup(data, pin: current) {
                onDone("Đã khôi phục tin nhắn + định danh")
                dismiss()
            } else {
                error = "Sai mã PIN hoặc file sao lưu không hợp lệ"
            }
        }
    }
}

/// Full-screen PIN lock: shown instead of the chat while the encrypted
/// history has no key (new device / reinstall / wiped Keychain).
private struct ZheePINLockView: View {
    @State private var pin = ""
    @State private var error = ""
    @State private var busy = false
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.gray.opacity(0.12))
                    Image(systemName: "lock").font(.system(size: 40)).foregroundColor(.secondary)
                }
                .frame(width: 88, height: 88)
                Text("Tin nhắn được mã hóa đầu cuối")
                    .font(.headline)
                Text("Nhập mã PIN để mở khóa và khôi phục tin nhắn.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                SecureField("Mã PIN (6 số)", text: $pin)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .onChange(of: pin) { _ in
                        if pin.count == ZheePINVault.pinLength { unlock() }
                    }
                if !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Button {
                    unlock()
                } label: {
                    if busy {
                        ProgressView()
                    } else {
                        Text("Mở khóa")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!ZheePINVault.isValidPIN(pin) || busy)
                Button("Quên mã PIN?") { showResetConfirm = true }
                    .font(.caption)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.top, 80)
            .padding(.horizontal)
        }
        .confirmationDialog("Quên mã PIN?", isPresented: $showResetConfirm) {
            Button("Xóa lịch sử mã hóa, bắt đầu mới", role: .destructive) {
                ZheeChatStore.shared.resetEncryptedHistory()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Không có mã PIN thì không giải mã được lịch sử cũ. Xóa để bắt đầu mới.")
        }
    }

    private func unlock() {
        guard ZheePINVault.isValidPIN(pin), !busy else { return }
        busy = true
        defer { busy = false }
        if ZheeChatStore.shared.unlock(with: pin) {
            // isLocked flips false → overlay disappears.
        } else {
            error = "Sai mã PIN, thử lại"
            pin = ""
        }
    }
}
