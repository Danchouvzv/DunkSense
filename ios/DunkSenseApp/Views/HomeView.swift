import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var metricsManager: MetricsManager
    @State private var recentMetrics: [JumpMetric] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome header
                    welcomeHeader
                    
                    // Quick stats
                    quickStatsSection
                    
                    // Recent activity chart
                    recentActivityChart
                    
                    // Quick actions
                    quickActionsSection
                    
                    // Training recommendations
                    trainingRecommendations
                }
                .padding()
            }
            .navigationTitle("DunkSense")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }
    
    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(appState.currentUser?.name ?? "Athlete")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Ready to jump higher?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            AsyncImage(url: appState.currentUser?.avatarURL) { image in
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
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Best Jump",
                value: String(format: "%.1f cm", metricsManager.personalBest?.jumpHeight ?? 0),
                icon: "arrow.up.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "This Week",
                value: "\(metricsManager.weeklyJumps)",
                icon: "calendar",
                color: .blue
            )
            
            StatCard(
                title: "Avg. Height",
                value: String(format: "%.1f cm", metricsManager.averageHeight),
                icon: "chart.bar.fill",
                color: .orange
            )
            
            StatCard(
                title: "Consistency",
                value: String(format: "%.0f%%", metricsManager.consistencyScore * 100),
                icon: "target",
                color: .purple
            )
        }
    }
    
    private var recentActivityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if recentMetrics.isEmpty {
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No recent activity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Start jumping to see your progress!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
            } else {
                Chart(recentMetrics) { metric in
                    LineMark(
                        x: .value("Date", metric.timestamp),
                        y: .value("Height", metric.jumpHeight)
                    )
                    .foregroundStyle(.blue)
                    .symbol(Circle())
                    
                    PointMark(
                        x: .value("Date", metric.timestamp),
                        y: .value("Height", metric.jumpHeight)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    title: "Start Jump Session",
                    icon: "camera.fill",
                    color: .blue
                ) {
                    appState.selectedTab = .capture
                }
                
                QuickActionCard(
                    title: "View Progress",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                ) {
                    appState.selectedTab = .progress
                }
                
                QuickActionCard(
                    title: "Training Plan",
                    icon: "figure.strengthtraining.traditional",
                    color: .orange
                ) {
                    // Navigate to training plan
                }
                
                QuickActionCard(
                    title: "Community",
                    icon: "person.3.fill",
                    color: .purple
                ) {
                    appState.selectedTab = .community
                }
            }
        }
    }
    
    private var trainingRecommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                RecommendationCard(
                    title: "Improve Takeoff Power",
                    description: "Your jump analysis shows potential for better takeoff mechanics.",
                    icon: "bolt.fill",
                    color: .yellow
                )
                
                RecommendationCard(
                    title: "Consistency Training",
                    description: "Focus on consistent form to improve your jump reliability.",
                    icon: "target",
                    color: .blue
                )
                
                RecommendationCard(
                    title: "Recovery Day",
                    description: "You've been training hard. Consider a rest day.",
                    icon: "bed.double.fill",
                    color: .green
                )
            }
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        
        do {
            // Load recent metrics
            recentMetrics = try await metricsManager.getRecentMetrics(days: 7)
            
            // Update metrics manager stats
            await metricsManager.updateStats()
            
        } catch {
            print("Failed to load home data: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(MetricsManager())
} 