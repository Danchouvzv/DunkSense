import SwiftUI
import Charts

struct ProgressView: View {
    @EnvironmentObject var metricsManager: MetricsManager
    @State private var selectedPeriod: TimePeriod = .week
    @State private var metrics: [JumpMetric] = []
    @State private var isLoading = true
    @State private var showingDetailedStats = false
    
    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            case .all: return 0
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Period selector
                    periodSelector
                    
                    // Summary stats
                    summaryStats
                    
                    // Progress chart
                    progressChart
                    
                    // Detailed metrics
                    detailedMetrics
                    
                    // Personal records
                    personalRecords
                    
                    // Training insights
                    trainingInsights
                }
                .padding()
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Details") {
                        showingDetailedStats = true
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showingDetailedStats) {
            DetailedStatsView(metrics: metrics)
        }
    }
    
    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedPeriod) { _ in
            Task {
                await loadData()
            }
        }
    }
    
    private var summaryStats: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            SummaryStatCard(
                title: "Total Jumps",
                value: "\(metrics.count)",
                change: calculateChange(for: \.count),
                icon: "figure.jumprope",
                color: .blue
            )
            
            SummaryStatCard(
                title: "Best Jump",
                value: String(format: "%.1f cm", metrics.map(\.jumpHeight).max() ?? 0),
                change: calculateChange(for: \.jumpHeight),
                icon: "arrow.up.circle.fill",
                color: .green
            )
            
            SummaryStatCard(
                title: "Average Height",
                value: String(format: "%.1f cm", metrics.map(\.jumpHeight).average),
                change: calculateChange(for: \.jumpHeight, useAverage: true),
                icon: "chart.bar.fill",
                color: .orange
            )
            
            SummaryStatCard(
                title: "Consistency",
                value: String(format: "%.0f%%", calculateConsistency() * 100),
                change: nil,
                icon: "target",
                color: .purple
            )
        }
    }
    
    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Jump Height Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            if metrics.isEmpty {
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else {
                Chart {
                    ForEach(metrics) { metric in
                        LineMark(
                            x: .value("Date", metric.timestamp),
                            y: .value("Height", metric.jumpHeight)
                        )
                        .foregroundStyle(.blue)
                        .symbol(Circle())
                        
                        AreaMark(
                            x: .value("Date", metric.timestamp),
                            y: .value("Height", metric.jumpHeight)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                    }
                    
                    // Trend line
                    if let trendLine = calculateTrendLine() {
                        LineMark(
                            x: .value("Start", trendLine.start.date),
                            y: .value("Height", trendLine.start.height)
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        
                        LineMark(
                            x: .value("End", trendLine.end.date),
                            y: .value("Height", trendLine.end.height)
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
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
    
    private var detailedMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "Avg. Flight Time",
                    value: String(format: "%.2f s", metrics.map(\.flightTime).average),
                    icon: "timer",
                    color: .blue
                )
                
                MetricCard(
                    title: "Avg. Contact Time",
                    value: String(format: "%.3f s", metrics.map(\.contactTime).average),
                    icon: "stopwatch",
                    color: .green
                )
                
                MetricCard(
                    title: "Avg. Takeoff Velocity",
                    value: String(format: "%.1f m/s", metrics.map(\.takeoffVelocity).average),
                    icon: "speedometer",
                    color: .orange
                )
                
                MetricCard(
                    title: "Avg. Symmetry",
                    value: String(format: "%.0f%%", metrics.map(\.symmetryScore).average * 100),
                    icon: "arrow.left.and.right",
                    color: .purple
                )
                
                MetricCard(
                    title: "Avg. Technique",
                    value: String(format: "%.0f%%", metrics.map(\.techniqueScore).average * 100),
                    icon: "checkmark.seal",
                    color: .pink
                )
                
                MetricCard(
                    title: "Avg. Landing Force",
                    value: String(format: "%.1f N", metrics.map(\.landingForce).average),
                    icon: "arrow.down.circle",
                    color: .red
                )
            }
        }
    }
    
    private var personalRecords: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Records")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let bestJump = metrics.max(by: { $0.jumpHeight < $1.jumpHeight }) {
                    RecordCard(
                        title: "Highest Jump",
                        value: String(format: "%.1f cm", bestJump.jumpHeight),
                        date: bestJump.timestamp,
                        icon: "trophy.fill",
                        color: .gold
                    )
                }
                
                if let bestTechnique = metrics.max(by: { $0.techniqueScore < $1.techniqueScore }) {
                    RecordCard(
                        title: "Best Technique",
                        value: String(format: "%.0f%%", bestTechnique.techniqueScore * 100),
                        date: bestTechnique.timestamp,
                        icon: "star.fill",
                        color: .blue
                    )
                }
                
                if let bestSymmetry = metrics.max(by: { $0.symmetryScore < $1.symmetryScore }) {
                    RecordCard(
                        title: "Best Symmetry",
                        value: String(format: "%.0f%%", bestSymmetry.symmetryScore * 100),
                        date: bestSymmetry.timestamp,
                        icon: "arrow.left.and.right.circle.fill",
                        color: .green
                    )
                }
            }
        }
    }
    
    private var trainingInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InsightCard(
                    title: "Improvement Trend",
                    insight: getTrendInsight(),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                InsightCard(
                    title: "Consistency Analysis",
                    insight: getConsistencyInsight(),
                    icon: "target",
                    color: .green
                )
                
                InsightCard(
                    title: "Training Frequency",
                    insight: getFrequencyInsight(),
                    icon: "calendar",
                    color: .orange
                )
            }
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        
        do {
            let days = selectedPeriod.days
            if days > 0 {
                metrics = try await metricsManager.getRecentMetrics(days: days)
            } else {
                metrics = try await metricsManager.getAllMetrics()
            }
        } catch {
            print("Failed to load progress data: \(error)")
            metrics = []
        }
        
        isLoading = false
    }
    
    private func calculateChange(for keyPath: KeyPath<JumpMetric, Double>, useAverage: Bool = false) -> Double? {
        guard metrics.count >= 2 else { return nil }
        
        let sortedMetrics = metrics.sorted { $0.timestamp < $1.timestamp }
        let halfPoint = sortedMetrics.count / 2
        
        let firstHalf = Array(sortedMetrics.prefix(halfPoint))
        let secondHalf = Array(sortedMetrics.suffix(sortedMetrics.count - halfPoint))
        
        let firstValue = useAverage ? firstHalf.map { $0[keyPath: keyPath] }.average : firstHalf.map { $0[keyPath: keyPath] }.max() ?? 0
        let secondValue = useAverage ? secondHalf.map { $0[keyPath: keyPath] }.average : secondHalf.map { $0[keyPath: keyPath] }.max() ?? 0
        
        return ((secondValue - firstValue) / firstValue) * 100
    }
    
    private func calculateChange(for keyPath: KeyPath<[JumpMetric], Int>) -> Double? {
        // For count-based metrics
        return nil // Simplified for now
    }
    
    private func calculateConsistency() -> Double {
        guard !metrics.isEmpty else { return 0 }
        
        let heights = metrics.map(\.jumpHeight)
        let average = heights.average
        let variance = heights.map { pow($0 - average, 2) }.average
        let standardDeviation = sqrt(variance)
        
        // Consistency score: higher is better (lower standard deviation relative to mean)
        return max(0, 1 - (standardDeviation / average))
    }
    
    private func calculateTrendLine() -> (start: (date: Date, height: Double), end: (date: Date, height: Double))? {
        guard metrics.count >= 2 else { return nil }
        
        let sortedMetrics = metrics.sorted { $0.timestamp < $1.timestamp }
        
        // Simple linear regression
        let n = Double(sortedMetrics.count)
        let sumX = sortedMetrics.enumerated().map { Double($0.offset) }.reduce(0, +)
        let sumY = sortedMetrics.map(\.jumpHeight).reduce(0, +)
        let sumXY = sortedMetrics.enumerated().map { Double($0.offset) * $0.element.jumpHeight }.reduce(0, +)
        let sumX2 = sortedMetrics.enumerated().map { pow(Double($0.offset), 2) }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - pow(sumX, 2))
        let intercept = (sumY - slope * sumX) / n
        
        let startHeight = intercept
        let endHeight = slope * (n - 1) + intercept
        
        return (
            start: (date: sortedMetrics.first!.timestamp, height: startHeight),
            end: (date: sortedMetrics.last!.timestamp, height: endHeight)
        )
    }
    
    private func getTrendInsight() -> String {
        guard let trendLine = calculateTrendLine() else {
            return "Not enough data to determine trend"
        }
        
        let improvement = trendLine.end.height - trendLine.start.height
        
        if improvement > 2 {
            return "Great progress! You're improving consistently."
        } else if improvement > 0 {
            return "Steady improvement. Keep up the good work!"
        } else if improvement > -2 {
            return "Performance is stable. Consider varying your training."
        } else {
            return "Consider adjusting your training approach."
        }
    }
    
    private func getConsistencyInsight() -> String {
        let consistency = calculateConsistency()
        
        if consistency > 0.8 {
            return "Excellent consistency in your jumps!"
        } else if consistency > 0.6 {
            return "Good consistency. Focus on technique refinement."
        } else if consistency > 0.4 {
            return "Work on jump consistency through repetition."
        } else {
            return "Focus on basic technique and form."
        }
    }
    
    private func getFrequencyInsight() -> String {
        let daysWithJumps = Set(metrics.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        let totalDays = selectedPeriod.days > 0 ? selectedPeriod.days : 30
        let frequency = Double(daysWithJumps) / Double(totalDays)
        
        if frequency > 0.7 {
            return "Excellent training frequency!"
        } else if frequency > 0.5 {
            return "Good training consistency."
        } else if frequency > 0.3 {
            return "Try to train more regularly for better results."
        } else {
            return "Increase training frequency for optimal progress."
        }
    }
}

// MARK: - Supporting Views

struct SummaryStatCard: View {
    let title: String
    let value: String
    let change: Double?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                if let change = change {
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption)
                        Text(String(format: "%.1f%%", abs(change)))
                            .font(.caption)
                    }
                    .foregroundColor(change >= 0 ? .green : .red)
                }
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

struct MetricCard: View {
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecordCard: View {
    let title: String
    let value: String
    let date: Date
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
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(date, style: .date)
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

struct InsightCard: View {
    let title: String
    let insight: String
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
                
                Text(insight)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension Array where Element == Double {
    var average: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
    }
}

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

#Preview {
    ProgressView()
        .environmentObject(MetricsManager())
} 