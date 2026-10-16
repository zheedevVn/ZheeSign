import SwiftUI

/// Hand-drawn outline icons (no SF Symbols): every icon is a stroked Path
/// drawn in a 24x24 space, scaled to the requested size.
enum ZheeOutlineIconKind {
    case chat, people, bell, menu, compose, antenna, globe, pin
    case lock, chevronLeft, send, mic, trash, play, pause
    case check
}

struct ZheeOutlineIcon: View {
    let kind: ZheeOutlineIconKind
    let size: CGFloat
    var color: Color = .primary

    init(_ kind: ZheeOutlineIconKind, size: CGFloat, color: Color = .primary) {
        self.kind = kind
        self.size = size
        self.color = color
    }

    var body: some View {
        let path = Path { path in
            let s = size / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
            }
            switch kind {
            case .chat:
                path.addRoundedRect(in: r(3, 4, 18, 12), cornerSize: CGSize(width: 4 * s, height: 4 * s))
                path.move(to: p(8, 16)); path.addLine(to: p(8, 21)); path.addLine(to: p(13, 16))
            case .people:
                path.addEllipse(in: r(5, 4, 6, 6))
                path.addEllipse(in: r(14.5, 3, 5, 5))
                path.move(to: p(2.5, 20)); path.addQuadCurve(to: p(13.5, 20), control: p(8, 10))
                path.move(to: p(13, 20)); path.addQuadCurve(to: p(21, 20), control: p(17, 13))
            case .bell:
                path.move(to: p(12, 3)); path.addLine(to: p(12, 5.5))
                path.move(to: p(5, 18)); path.addQuadCurve(to: p(19, 18), control: p(12, 0))
                path.move(to: p(4, 19.5)); path.addLine(to: p(20, 19.5))
                path.addEllipse(in: r(10.5, 20.5, 3, 2))
            case .menu:
                for y in [7, 12, 17] as [CGFloat] {
                    path.move(to: p(4, y)); path.addLine(to: p(20, y))
                }
            case .compose:
                path.addRoundedRect(in: r(3, 3, 18, 18), cornerSize: CGSize(width: 2 * s, height: 2 * s))
                path.move(to: p(5, 19)); path.addLine(to: p(14, 10))
                path.addLine(to: p(19, 5)); path.addLine(to: p(17, 11))
                path.closeSubpath()
            case .antenna:
                path.addEllipse(in: r(10.5, 15.5, 3, 3))
                path.move(to: p(7, 12)); path.addQuadCurve(to: p(17, 12), control: p(12, 4))
                path.move(to: p(4.5, 10)); path.addQuadCurve(to: p(19.5, 10), control: p(12, -1))
            case .globe:
                path.addEllipse(in: r(3.5, 3.5, 17, 17))
                path.addEllipse(in: r(8, 3.5, 8, 17))
                path.move(to: p(3.5, 12)); path.addLine(to: p(20.5, 12))
            case .pin:
                path.move(to: p(12, 21))
                path.addQuadCurve(to: p(12, 3), control: p(4.5, 12))
                path.addQuadCurve(to: p(12, 21), control: p(19.5, 12))
                path.addEllipse(in: r(8.5, 7, 7, 7))
            case .lock:
                path.move(to: p(7.5, 11))
                path.addQuadCurve(to: p(16.5, 11), control: p(12, 2))
                path.addRoundedRect(in: r(5, 11, 14, 10), cornerSize: CGSize(width: 2.5 * s, height: 2.5 * s))
                path.addEllipse(in: r(11, 14, 2, 2.5))
            case .chevronLeft:
                path.move(to: p(15, 4)); path.addLine(to: p(8, 12)); path.addLine(to: p(15, 20))
            case .send:
                path.move(to: p(3.5, 12.5)); path.addLine(to: p(20.5, 3.5))
                path.addLine(to: p(13.5, 13.5)); path.addLine(to: p(20.5, 20.5))
                path.closeSubpath()
            case .mic:
                path.addRoundedRect(in: r(9, 3, 6, 11), cornerSize: CGSize(width: 3 * s, height: 3 * s))
                path.move(to: p(5.5, 11)); path.addQuadCurve(to: p(18.5, 11), control: p(12, 21))
                path.move(to: p(12, 17.5)); path.addLine(to: p(12, 21))
                path.move(to: p(8.5, 21)); path.addLine(to: p(15.5, 21))
            case .trash:
                path.move(to: p(5, 6)); path.addLine(to: p(19, 6))
                path.move(to: p(9, 6)); path.addLine(to: p(9, 3.5))
                path.addLine(to: p(15, 3.5)); path.addLine(to: p(15, 6))
                path.move(to: p(6.5, 6)); path.addLine(to: p(7.5, 21))
                path.addLine(to: p(16.5, 21)); path.addLine(to: p(17.5, 6))
                path.move(to: p(10.5, 9.5)); path.addLine(to: p(11, 18))
                path.move(to: p(13.5, 9.5)); path.addLine(to: p(13, 18))
            case .check:
                path.move(to: p(4, 12.5)); path.addLine(to: p(9.5, 18.5)); path.addLine(to: p(20, 6.5))
            case .play:
                path.move(to: p(8, 5)); path.addLine(to: p(8, 19)); path.addLine(to: p(19, 12))
                path.closeSubpath()
            case .pause:
                path.addRoundedRect(in: r(6.5, 5, 4.5, 14), cornerSize: CGSize(width: 1.5 * s, height: 1.5 * s))
                path.addRoundedRect(in: r(13, 5, 4.5, 14), cornerSize: CGSize(width: 1.5 * s, height: 1.5 * s))
            }
        }
        Group {
            if kind == .play || kind == .pause {
                path.fill(color)
            } else {
                path.stroke(color, style: StrokeStyle(lineWidth: max(1.2, size * 0.075), lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}

/// Messenger-style recent-chats home for ZheeChat:
/// Đoạn chat (recent conversations) / Mọi người / Thông báo / Menu.

/// List time: today -> "HH:mm", this week -> "Thứ 5", older -> "dd/MM".
func zheeChatListTime(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    if cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
        switch cal.component(.weekday, from: date) {
        case 1: return "Chủ Nhật"
        case 2: return "Thứ 2"
        case 3: return "Thứ 3"
        case 4: return "Thứ 4"
        case 5: return "Thứ 5"
        case 6: return "Thứ 6"
        default: return "Thứ 7"
        }
    }
    let f = DateFormatter()
    f.dateFormat = "dd/MM"
    return f.string(from: date)
}

struct ZheeChatRootView: View {
    var body: some View {
        TabView {
            NavigationStack { ZheeChatListView() }
                .tabItem { Label { Text("Đoạn chat") } icon: { ZheeOutlineIcon(.chat, size: 24) } }
            NavigationStack { ZheePeopleView() }
                .tabItem { Label { Text("Mọi người") } icon: { ZheeOutlineIcon(.people, size: 24) } }
            NavigationStack { ZheeActivityListView() }
                .tabItem { Label { Text("Thông báo") } icon: { ZheeOutlineIcon(.bell, size: 24) } }
            NavigationStack { ZheeChatMenuView() }
                .tabItem { Label { Text("Menu") } icon: { ZheeOutlineIcon(.menu, size: 24) } }
        }
        // ZheeChat has its own TabView — hide the app tab bar so the
        // two floating pills never stack on top of each other.
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Đoạn chat

private struct ZheeChatListView: View {
    @StateObject private var store = ZheeChatStore.shared
    @StateObject private var identity = ZheeNostrIdentity.shared
    @State private var showNewDM = false
    @State private var showIdentity = false
    @State private var openDM: String?
    @State private var showDM = false

    var body: some View {
        Group {
            if store.conversations.isEmpty {
                VStack(spacing: 12) {
                    ZheeOutlineIcon(.chat, size: 44, color: .secondary)
                    Text("Chưa có đoạn chat nào")
                        .font(.headline)
                    Text("Mở Mesh gần, Nostr công khai, hoặc bắt đầu DM mới để chat.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List(store.conversations) { conv in
                    NavigationLink {
                        ZheeChatView(channel: conv.kind, peer: conv.peer)
                    } label: {
                        ZheeConversationRow(conv: conv)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Đoạn chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { showIdentity = true } label: {
                    ZheeChatRowAvatar(urlString: store.profiles[identity.publicKeyHex]?.picture, name: identity.displayName, size: 32)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNewDM = true } label: {
                    ZheeOutlineIcon(.compose, size: 20)
                }
            }
        }
        .sheet(isPresented: $showNewDM) {
            ZheeNewDMView { hex in
                showNewDM = false
                openDM = hex
                showDM = true
            }
        }
        .sheet(isPresented: $showIdentity) {
            ZheeChatIdentityView()
        }
        // navigationDestination(item:) needs iOS 17; the app targets 16.
        .navigationDestination(isPresented: $showDM) {
            ZheeChatView(channel: .dm, peer: openDM)
        }
        .onChange(of: showDM) { _ in if !showDM { openDM = nil } }
    }
}

private struct ZheeConversationRow: View {
    let conv: ZheeConversation

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if conv.peer != nil {
                    ZheeChatRowAvatar(urlString: conv.avatarURL, name: conv.avatarName, size: 56)
                } else {
                    ZheeChannelAvatar(kind: conv.kind, size: 56)
                }
                if conv.unread > 0 {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(conv.title)
                    .font(.headline)
                    .fontWeight(conv.unread > 0 ? .bold : .regular)
                    .lineLimit(1)
                Text(conv.preview)
                    .font(.subheadline)
                    .foregroundColor(conv.unread > 0 ? .primary : .secondary)
                    .fontWeight(conv.unread > 0 ? .semibold : .regular)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(zheeChatListTime(conv.date))
                    .font(.caption)
                    .foregroundColor(conv.unread > 0 ? .blue : .secondary)
                if conv.isOnline {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// Round avatar for a DM peer: picture URL if known, else initial letter.
struct ZheeChatRowAvatar: View {
    let urlString: String?
    let name: String
    let size: CGFloat

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
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialCircle: some View {
        ZStack {
            Circle().fill(Color.gray.opacity(0.3))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

/// Colored circle with an outline icon for channel rows (Mesh / Nostr / Geo).
private struct ZheeChannelAvatar: View {
    let kind: ZheeChatChannel
    let size: CGFloat

    private var icon: ZheeOutlineIconKind {
        switch kind {
        case .mesh: return .antenna
        case .nostr: return .globe
        case .geo: return .pin
        case .dm: return .chat
        }
    }

    private var color: Color {
        switch kind {
        case .mesh: return .blue
        case .nostr: return .purple
        case .geo: return .green
        case .dm: return .gray
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.15))
            ZheeOutlineIcon(icon, size: size * 0.38, color: color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Mọi người

private struct ZheePeopleView: View {
    @StateObject private var store = ZheeChatStore.shared
    @ObservedObject private var mesh = ZheeChatStore.shared.mesh

    private var knownPeers: [(pubkey: String, name: String, picture: String?)] {
        let dmPeers = Set(store.dmConversations.map { $0.peer })
        return store.profiles
            .filter { !dmPeers.contains($0.key) }
            .map { (pubkey: $0.key, name: store.displayName(for: $0.key), picture: $0.value.picture) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if !mesh.connectedPeerNames.isEmpty {
                Section("Đang hoạt động — gần bạn") {
                    ForEach(mesh.connectedPeerNames, id: \.self) { name in
                        HStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                ZheeChatRowAvatar(urlString: nil, name: name, size: 44)
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.headline).lineLimit(1)
                                Text("Mesh gần · đang hoạt động")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            if !store.dmConversations.isEmpty {
                Section("Tin nhắn gần đây") {
                    ForEach(store.dmConversations, id: \.peer) { conv in
                        NavigationLink {
                            ZheeChatView(channel: .dm, peer: conv.peer)
                        } label: {
                            HStack(spacing: 12) {
                                ZheeChatRowAvatar(urlString: store.profiles[conv.peer]?.picture, name: store.displayName(for: conv.peer), size: 44)
                                Text(store.displayName(for: conv.peer))
                                    .font(.headline)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            if !knownPeers.isEmpty {
                Section("Đã biết trên Nostr") {
                    ForEach(knownPeers, id: \.pubkey) { person in
                        NavigationLink {
                            ZheeChatView(channel: .dm, peer: person.pubkey)
                        } label: {
                            HStack(spacing: 12) {
                                ZheeChatRowAvatar(urlString: person.picture, name: person.name, size: 44)
                                Text(person.name)
                                    .font(.headline)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            if mesh.connectedPeerNames.isEmpty && store.dmConversations.isEmpty && knownPeers.isEmpty {
                Text("Chưa có ai quanh đây. Mở Mesh gần hoặc nhắn DM để gặp người mới.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Mọi người")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Thông báo

private struct ZheeActivityListView: View {
    @StateObject private var store = ZheeChatStore.shared

    var body: some View {
        Group {
            if store.activities.isEmpty {
                VStack(spacing: 12) {
                    ZheeOutlineIcon(.bell, size: 44, color: .secondary)
                    Text("Chưa có thông báo nào")
                        .font(.headline)
                    Text("Bạn bè Mesh vào gần, DM mới và trạng thái relay sẽ hiện ở đây.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                List(store.activities) { activity in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.blue.opacity(0.15))
                            ZheeOutlineIcon(activity.icon, size: 18, color: .blue)
                        }
                        .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.text)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text(zheeChatListTime(activity.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Thông báo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Menu

private struct ZheeChatMenuView: View {
    @StateObject private var store = ZheeChatStore.shared
    @StateObject private var identity = ZheeNostrIdentity.shared
    @State private var showIdentity = false
    @State private var showWipeConfirm = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    ZheeChatRowAvatar(urlString: store.profiles[identity.publicKeyHex]?.picture, name: identity.displayName, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(identity.displayName)
                            .font(.headline)
                        Text("npub1" + String(identity.publicKeyHex.prefix(12)) + "…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(store.pinEnabled ? "Mã hóa đầu cuối: Bật (mã PIN)" : "Mã hóa đầu cuối: Tắt")
                            .font(.caption)
                            .foregroundColor(store.pinEnabled ? .green : .secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                Button("Định danh & mã PIN") { showIdentity = true }
                Button("Đặt / Đổi mã PIN") { showIdentity = true }
            } header: {
                Text("Cài đặt")
            } footer: {
                Text("Mã PIN bảo vệ lịch sử chat và sao lưu — giống Messenger. Quên PIN thì lịch sử mã hóa không khôi phục được.")
            }
            Section {
                Button("Emergency Wipe", role: .destructive) { showWipeConfirm = true }
            } header: {
                Text("Nguy hiểm")
            } footer: {
                Text("Xóa vĩnh viễn định danh (npub/nsec) và toàn bộ lịch sử chat.")
            }
            Section {
                Text("ZheeChat trong ZheeSign 1.7.37")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showIdentity) {
            ZheeChatIdentityView()
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
}
