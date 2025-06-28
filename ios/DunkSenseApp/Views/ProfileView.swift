import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    profileHeader
                    
                    // Stats overview
                    statsOverview
                    
                    // Menu sections
                    menuSections
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditProfile = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            AsyncImage(url: appState.currentUser?.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 3)
            )
            
            // User info
            VStack(spacing: 4) {
                Text(appState.currentUser?.name ?? "Unknown User")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(appState.currentUser?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let user = appState.currentUser {
                    HStack(spacing: 16) {
                        Label("\(user.age) years", systemImage: "calendar")
                        Label("\(user.height) cm", systemImage: "ruler")
                        Label(String(format: "%.1f kg", user.weight), systemImage: "scalemass")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // Sport level badge
            if let user = appState.currentUser {
                Text(user.sportLevel.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(user.sportLevel.color.opacity(0.2))
                    .foregroundColor(user.sportLevel.color)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var statsOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Stats")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ProfileStatCard(
                    title: "Total Jumps",
                    value: "156",
                    icon: "figure.jumprope",
                    color: .blue
                )
                
                ProfileStatCard(
                    title: "Personal Best",
                    value: "67.3 cm",
                    icon: "trophy.fill",
                    color: .gold
                )
                
                ProfileStatCard(
                    title: "This Week",
                    value: "12",
                    icon: "calendar",
                    color: .green
                )
            }
        }
    }
    
    private var menuSections: some View {
        VStack(spacing: 16) {
            // Training section
            MenuSection(title: "Training") {
                MenuRow(
                    title: "Training History",
                    icon: "clock.arrow.circlepath",
                    action: { /* Navigate to training history */ }
                )
                
                MenuRow(
                    title: "Goals & Targets",
                    icon: "target",
                    action: { /* Navigate to goals */ }
                )
                
                MenuRow(
                    title: "Achievements",
                    icon: "trophy",
                    action: { /* Navigate to achievements */ }
                )
            }
            
            // Data section
            MenuSection(title: "Data & Privacy") {
                MenuRow(
                    title: "Export Data",
                    icon: "square.and.arrow.up",
                    action: { /* Export data */ }
                )
                
                MenuRow(
                    title: "Privacy Settings",
                    icon: "lock.shield",
                    action: { /* Privacy settings */ }
                )
            }
            
            // App section
            MenuSection(title: "App") {
                MenuRow(
                    title: "Settings",
                    icon: "gearshape",
                    action: { showingSettings = true }
                )
                
                MenuRow(
                    title: "Help & Support",
                    icon: "questionmark.circle",
                    action: { /* Help & support */ }
                )
                
                MenuRow(
                    title: "About DunkSense",
                    icon: "info.circle",
                    action: { showingAbout = true }
                )
            }
            
            // Sign out
            Button(action: {
                appState.logout()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    
                    Text("Sign Out")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Supporting Views

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

struct MenuSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
    }
}

struct MenuRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var sportLevel: User.SportLevel = .beginner
    @State private var goals: [String] = []
    @State private var newGoal: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: $name)
                    
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    
                    TextField("Height (cm)", text: $height)
                        .keyboardType(.numberPad)
                    
                    TextField("Weight (kg)", text: $weight)
                        .keyboardType(.decimalPad)
                }
                
                Section("Athletic Profile") {
                    Picker("Sport Level", selection: $sportLevel) {
                        ForEach(User.SportLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Goals") {
                    ForEach(goals, id: \.self) { goal in
                        HStack {
                            Text(goal)
                            Spacer()
                            Button("Remove") {
                                goals.removeAll { $0 == goal }
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        TextField("Add new goal", text: $newGoal)
                        
                        Button("Add") {
                            if !newGoal.isEmpty {
                                goals.append(newGoal)
                                newGoal = ""
                            }
                        }
                        .disabled(newGoal.isEmpty)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    private func loadCurrentProfile() {
        guard let user = appState.currentUser else { return }
        
        name = user.name
        age = "\(user.age)"
        height = "\(user.height)"
        weight = String(format: "%.1f", user.weight)
        sportLevel = user.sportLevel
        goals = user.goals
    }
    
    private func saveProfile() {
        // Validate and save profile
        guard let ageInt = Int(age),
              let heightInt = Int(height),
              let weightDouble = Double(weight) else {
            return
        }
        
        let updatedUser = User(
            id: appState.currentUser?.id ?? "",
            name: name,
            email: appState.currentUser?.email ?? "",
            avatarURL: appState.currentUser?.avatarURL,
            createdAt: appState.currentUser?.createdAt ?? Date(),
            age: ageInt,
            height: heightInt,
            weight: weightDouble,
            sportLevel: sportLevel,
            goals: goals
        )
        
        appState.updateUser(updatedUser)
        dismiss()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = true
    @State private var hapticFeedback = true
    @State private var autoSave = true
    @State private var videoQuality = "High"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }
                
                Section("Recording") {
                    Toggle("Auto-save Recordings", isOn: $autoSave)
                    
                    Picker("Video Quality", selection: $videoQuality) {
                        Text("Low").tag("Low")
                        Text("Medium").tag("Medium")
                        Text("High").tag("High")
                    }
                }
                
                Section("Data") {
                    Button("Clear Cache") {
                        // Clear cache
                    }
                    
                    Button("Reset All Settings") {
                        // Reset settings
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
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

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // App icon and info
                    VStack(spacing: 12) {
                        Image(systemName: "basketball.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)
                        
                        Text("DunkSense AI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Your AI-powered vertical jump coach")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        FeatureRow(
                            icon: "camera.viewfinder",
                            title: "AI Jump Analysis",
                            description: "Computer vision powered jump measurement"
                        )
                        
                        FeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Progress Tracking",
                            description: "Detailed analytics and progress visualization"
                        )
                        
                        FeatureRow(
                            icon: "figure.strengthtraining.traditional",
                            title: "Personalized Training",
                            description: "AI-generated workout recommendations"
                        )
                    }
                    
                    // Legal
                    VStack(spacing: 8) {
                        Button("Privacy Policy") {
                            // Open privacy policy
                        }
                        
                        Button("Terms of Service") {
                            // Open terms of service
                        }
                        
                        Button("Contact Support") {
                            // Open support
                        }
                    }
                    .font(.subheadline)
                    
                    Text("© 2024 DunkSense AI. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .padding()
            }
            .navigationTitle("About")
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension User.SportLevel {
    var color: Color {
        switch self {
        case .beginner:
            return .green
        case .intermediate:
            return .orange
        case .advanced:
            return .red
        case .professional:
            return .purple
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
} 