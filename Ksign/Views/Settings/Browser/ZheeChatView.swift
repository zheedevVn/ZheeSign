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

    private var messages: [ZheeChatMessage] {
        store.messages(in: channel)
    }

    var body: some View {
        VStack(spacing: 0) {
            channelPicker
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
            if let text = store.pendingShareText {
                draft = text
                store.pendingShareText = nil
            }
        }
        .navigationTitle("ZheeChat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showIdentity = true
                } label: {
                    Image(systemName: "person.crop.circle")
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

    private var channelPicker: some View {
        Picker("Kênh", selection: $channel) {
            ForEach(ZheeChatChannel.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onTapGesture(count: 3) {
            // Panic gesture: triple-tap the channel picker.
            showWipeConfirm = true
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
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.green)
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
            Image(systemName: "location.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
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
        .padding(.top, 60)
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
            Spacer()
            Text(channel.subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
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
            Image(systemName: channel == .mesh ? "antenna.radiowaves.left.and.right" : "globe")
                .font(.largeTitle)
                .foregroundColor(.secondary)
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
                Text(message.text)
                    .font(.body)
                    .foregroundColor(message.isMine ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isMine ? Color.blue : Color(.secondarySystemBackground))
                    )
                if message.hasVoice {
                    ZheeVoicePlayButton(audio: store.voiceData(for: message.id))
                }
                Text(timeText(message.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !message.isMine { Spacer(minLength: 48) }
        }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if recorder.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Đang ghi \(String(format: "%.0f", recorder.elapsed))s — thả để gửi")
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal)
            }
            HStack(spacing: 8) {
                TextField("Nhắn tin…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit { send() }
                if channel == .mesh {
                    Image(systemName: "mic.fill")
                        .font(.body)
                        .padding(10)
                        .background(Circle().fill(recorder.isRecording ? Color.red : Color.gray.opacity(0.25)))
                        .foregroundColor(recorder.isRecording ? .white : .primary)
                        .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                            if pressing { recorder.start() } else { recorder.stop() }
                        }, perform: {})
                }
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.body)
                        .padding(10)
                        .background(Circle().fill(canSend ? Color.blue : Color.gray.opacity(0.4)))
                        .foregroundColor(.white)
                }
                .disabled(!canSend)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
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
                    Image(systemName: "chevron.left")
                }
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.green)
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
                    Image(systemName: "paperplane.fill")
                        .font(.body)
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
private struct ZheeNewDMView: View {
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

/// Play button for a voice (PTT) message.
private struct ZheeVoicePlayButton: View {
    @StateObject private var player = ZheeVoicePlayer()
    let audio: Data?

    var body: some View {
        Button {
            if let audio { player.play(audio) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption)
                Text(player.isPlaying ? "Đang phát…" : "Nghe thoại")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.green.opacity(0.2)))
            .foregroundColor(.green)
        }
        .disabled(audio == nil)
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
private struct ZheeChatIdentityView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var identity = ZheeNostrIdentity.shared
    @State private var relaysText = ""
    @State private var importText = ""
    @State private var notice = ""
    @State private var showRotateConfirm = false
    @State private var showClearConfirm = false
    @State private var showWipeConfirm = false
    @State private var initialDisplayName = ""

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
        }
    }
}
