import SwiftUI

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
                .tabItem { Label("Đoạn chat", systemImage: "message") }
            NavigationStack { ZheePeopleView() }
                .tabItem { Label("Mọi người", systemImage: "person.2") }
            NavigationStack { ZheeActivityListView() }
                .tabItem { Label("Thông báo", systemImage: "bell") }
            NavigationStack { ZheeChatMenuView() }
                .tabItem { Label("Menu", systemImage: "line.3.horizontal") }
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
                    Image(systemName: "message").font(.system(size: 44)).foregroundColor(.secondary)
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
                    Image(systemName: "square.and.pencil").font(.system(size: 20))
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

    /// SF Symbols (Apple outline) — giong icon Cài đặt của Apple.
    private var icon: String {
        switch kind {
        case .mesh: return "wifi"
        case .nostr: return "globe"
        case .geo: return "mappin"
        case .dm: return "message"
        }
    }

    private var gradient: LinearGradient {
        switch kind {
        case .mesh:
            return LinearGradient(colors: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.02, green: 0.71, blue: 0.83)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .nostr:
            return LinearGradient(colors: [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.93, green: 0.28, blue: 0.60)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .geo:
            return LinearGradient(colors: [Color(red: 0.13, green: 0.77, blue: 0.37), Color(red: 0.08, green: 0.72, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dm:
            return LinearGradient(colors: [Color(red: 0.42, green: 0.45, blue: 0.50), Color(red: 0.61, green: 0.64, blue: 0.69)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(gradient)
            Image(systemName: icon).font(.system(size: size * 0.5, weight: .semibold)).foregroundColor(.white)
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
                    Image(systemName: "bell").font(.system(size: 44)).foregroundColor(.secondary)
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
                            Image(systemName: activity.icon).font(.system(size: 18)).foregroundColor(.blue)
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
                Text("ZheeChat trong ZheeSign 1.7.42")
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
