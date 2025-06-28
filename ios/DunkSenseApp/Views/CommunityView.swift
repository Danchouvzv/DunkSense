import SwiftUI

struct CommunityView: View {
    @State private var selectedTab: CommunityTab = .leaderboard
    @State private var leaderboardData: [LeaderboardEntry] = []
    @State private var challenges: [Challenge] = []
    @State private var isLoading = true
    
    enum CommunityTab: String, CaseIterable {
        case leaderboard = "Leaderboard"
        case challenges = "Challenges"
        case friends = "Friends"
        
        var icon: String {
            switch self {
            case .leaderboard: return "trophy.fill"
            case .challenges: return "target"
            case .friends: return "person.2.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                
                // Content
                TabView(selection: $selectedTab) {
                    LeaderboardView(data: leaderboardData)
                        .tag(CommunityTab.leaderboard)
                    
                    ChallengesView(challenges: challenges)
                        .tag(CommunityTab.challenges)
                    
                    FriendsView()
                        .tag(CommunityTab.friends)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CommunityTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        
        // Simulate loading data
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock data
        leaderboardData = generateMockLeaderboard()
        challenges = generateMockChallenges()
        
        isLoading = false
    }
    
    private func generateMockLeaderboard() -> [LeaderboardEntry] {
        return [
            LeaderboardEntry(rank: 1, name: "Alex Johnson", height: 72.5, avatar: nil),
            LeaderboardEntry(rank: 2, name: "Sarah Chen", height: 68.3, avatar: nil),
            LeaderboardEntry(rank: 3, name: "Mike Davis", height: 65.7, avatar: nil),
            LeaderboardEntry(rank: 4, name: "Emma Wilson", height: 63.2, avatar: nil),
            LeaderboardEntry(rank: 5, name: "James Brown", height: 61.8, avatar: nil),
            LeaderboardEntry(rank: 6, name: "Lisa Garcia", height: 59.4, avatar: nil),
            LeaderboardEntry(rank: 7, name: "You", height: 57.2, avatar: nil, isCurrentUser: true),
            LeaderboardEntry(rank: 8, name: "Tom Miller", height: 55.9, avatar: nil),
            LeaderboardEntry(rank: 9, name: "Anna Lee", height: 54.1, avatar: nil),
            LeaderboardEntry(rank: 10, name: "David Kim", height: 52.7, avatar: nil)
        ]
    }
    
    private func generateMockChallenges() -> [Challenge] {
        return [
            Challenge(
                id: "1",
                title: "Weekly Jump Challenge",
                description: "Complete 50 jumps this week",
                type: .weekly,
                progress: 32,
                target: 50,
                reward: "100 XP + Badge",
                endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
                participants: 156
            ),
            Challenge(
                id: "2",
                title: "Height Master",
                description: "Achieve a 70cm vertical jump",
                type: .personal,
                progress: 67,
                target: 70,
                reward: "Elite Badge",
                endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
                participants: 1
            ),
            Challenge(
                id: "3",
                title: "Consistency King",
                description: "Jump every day for 7 days",
                type: .streak,
                progress: 4,
                target: 7,
                reward: "Consistency Badge",
                endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
                participants: 89
            )
        ]
    }
}

// MARK: - Leaderboard View

struct LeaderboardView: View {
    let data: [LeaderboardEntry]
    @State private var selectedPeriod: LeaderboardPeriod = .thisWeek
    
    enum LeaderboardPeriod: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case allTime = "All Time"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Top 3 podium
                topThreePodium
                
                // Full leaderboard
                LazyVStack(spacing: 8) {
                    ForEach(data) { entry in
                        LeaderboardRow(entry: entry)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var topThreePodium: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Second place
            if data.count > 1 {
                PodiumCard(entry: data[1], position: 2)
            }
            
            // First place
            if !data.isEmpty {
                PodiumCard(entry: data[0], position: 1)
            }
            
            // Third place
            if data.count > 2 {
                PodiumCard(entry: data[2], position: 3)
            }
        }
        .padding(.horizontal)
    }
}

struct PodiumCard: View {
    let entry: LeaderboardEntry
    let position: Int
    
    private var height: CGFloat {
        switch position {
        case 1: return 120
        case 2: return 100
        case 3: return 80
        default: return 60
        }
    }
    
    private var color: Color {
        switch position {
        case 1: return .gold
        case 2: return .silver
        case 3: return .bronze
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            AsyncImage(url: entry.avatar) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 3)
            )
            
            // Name
            Text(entry.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            // Height
            Text(String(format: "%.1f cm", entry.height))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Position badge
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                
                Text("\(position)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(entry.rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(entry.isCurrentUser ? .blue : .primary)
                .frame(width: 30)
            
            // Avatar
            AsyncImage(url: entry.avatar) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Name
            Text(entry.name)
                .font(.subheadline)
                .fontWeight(entry.isCurrentUser ? .semibold : .regular)
                .foregroundColor(entry.isCurrentUser ? .blue : .primary)
            
            Spacer()
            
            // Height
            Text(String(format: "%.1f cm", entry.height))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(entry.isCurrentUser ? .blue : .secondary)
        }
        .padding()
        .background(entry.isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(entry.isCurrentUser ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Challenges View

struct ChallengesView: View {
    let challenges: [Challenge]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(challenges) { challenge in
                    ChallengeCard(challenge: challenge)
                }
            }
            .padding()
        }
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Type badge
                Text(challenge.type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(challenge.type.color.opacity(0.2))
                    .foregroundColor(challenge.type.color)
                    .cornerRadius(8)
            }
            
            // Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(challenge.progress)/\(challenge.target)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                ProgressView(value: Double(challenge.progress), total: Double(challenge.target))
                    .progressViewStyle(LinearProgressViewStyle(tint: challenge.type.color))
            }
            
            // Footer
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(challenge.participants)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Ends \(challenge.endDate, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Reward
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.orange)
                
                Text("Reward: \(challenge.reward)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Friends View

struct FriendsView: View {
    @State private var friends: [Friend] = []
    @State private var showingAddFriend = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Add friend button
                Button(action: {
                    showingAddFriend = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Add Friends")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Friends list
                if friends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No friends yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Add friends to compete and share your progress!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(friends) { friend in
                            FriendRow(friend: friend)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView()
        }
        .onAppear {
            loadFriends()
        }
    }
    
    private func loadFriends() {
        // Mock friends data
        friends = [
            Friend(id: "1", name: "John Doe", avatar: nil, bestJump: 65.2, isOnline: true),
            Friend(id: "2", name: "Jane Smith", avatar: nil, bestJump: 58.7, isOnline: false),
            Friend(id: "3", name: "Mike Johnson", avatar: nil, bestJump: 62.1, isOnline: true)
        ]
    }
}

struct FriendRow: View {
    let friend: Friend
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: friend.avatar) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                if friend.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            
            // Friend info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Best: \(String(format: "%.1f cm", friend.bestJump))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action button
            Button("Challenge") {
                // Send challenge
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by username or email", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                // Search results
                List(searchResults) { user in
                    HStack {
                        AsyncImage(url: user.avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Add") {
                            // Add friend
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                }
                
                Spacer()
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Data Models

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let height: Double
    let avatar: URL?
    let isCurrentUser: Bool
    
    init(rank: Int, name: String, height: Double, avatar: URL?, isCurrentUser: Bool = false) {
        self.rank = rank
        self.name = name
        self.height = height
        self.avatar = avatar
        self.isCurrentUser = isCurrentUser
    }
}

struct Challenge: Identifiable {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let progress: Int
    let target: Int
    let reward: String
    let endDate: Date
    let participants: Int
    
    enum ChallengeType {
        case weekly
        case personal
        case streak
        
        var displayName: String {
            switch self {
            case .weekly: return "Weekly"
            case .personal: return "Personal"
            case .streak: return "Streak"
            }
        }
        
        var color: Color {
            switch self {
            case .weekly: return .blue
            case .personal: return .green
            case .streak: return .orange
            }
        }
    }
}

struct Friend: Identifiable {
    let id: String
    let name: String
    let avatar: URL?
    let bestJump: Double
    let isOnline: Bool
}

// MARK: - Extensions

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let silver = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let bronze = Color(red: 0.8, green: 0.5, blue: 0.2)
}

#Preview {
    CommunityView()
} 