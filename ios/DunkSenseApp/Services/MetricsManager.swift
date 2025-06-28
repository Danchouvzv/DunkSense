import Foundation
import SwiftUI
import Combine

class MetricsManager: ObservableObject {
    @Published var recentMetrics: [JumpMetric] = []
    @Published var personalBest: JumpMetric?
    @Published var weeklyStats: WeeklyStats?
    @Published var isLoading = false
    @Published var error: MetricsError?
    
    private let networkManager = NetworkManager.shared
    private let cacheManager = CacheManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadCachedData()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .recordingCompleted)
            .sink { [weak self] notification in
                if let fileURL = notification.userInfo?["fileURL"] as? URL {
                    self?.processRecordedVideo(url: fileURL)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func loadRecentMetrics(limit: Int = 10) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let metrics = try await networkManager.fetchRecentMetrics(limit: limit)
            
            DispatchQueue.main.async {
                self.recentMetrics = metrics
                self.isLoading = false
            }
            
            // Cache the data
            cacheManager.cache(metrics, forKey: "recent_metrics")
            
        } catch {
            DispatchQueue.main.async {
                self.error = .loadingFailed(error.localizedDescription)
                self.isLoading = false
            }
        }
    }
    
    func loadMetricsForPeriod(_ period: TimePeriod) async -> [JumpMetric] {
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -period.days, to: endDate) ?? endDate
            
            return try await networkManager.fetchMetrics(from: startDate, to: endDate)
        } catch {
            DispatchQueue.main.async {
                self.error = .loadingFailed(error.localizedDescription)
            }
            return []
        }
    }
    
    func loadPersonalBest() async {
        do {
            let personalBest = try await networkManager.fetchPersonalBest()
            
            DispatchQueue.main.async {
                self.personalBest = personalBest
            }
            
            cacheManager.cache(personalBest, forKey: "personal_best")
            
        } catch {
            DispatchQueue.main.async {
                self.error = .loadingFailed(error.localizedDescription)
            }
        }
    }
    
    func loadWeeklyStats() async {
        do {
            let stats = try await networkManager.fetchWeeklyStats()
            
            DispatchQueue.main.async {
                self.weeklyStats = stats
            }
            
            cacheManager.cache(stats, forKey: "weekly_stats")
            
        } catch {
            DispatchQueue.main.async {
                self.error = .loadingFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Data Saving
    func saveJumpMetric(_ metric: JumpMetric) async {
        do {
            let savedMetric = try await networkManager.saveJumpMetric(metric)
            
            DispatchQueue.main.async {
                self.recentMetrics.insert(savedMetric, at: 0)
                
                // Update personal best if necessary
                if let currentBest = self.personalBest {
                    if savedMetric.jumpHeight > currentBest.jumpHeight {
                        self.personalBest = savedMetric
                    }
                } else {
                    self.personalBest = savedMetric
                }
                
                // Limit recent metrics to 50 items
                if self.recentMetrics.count > 50 {
                    self.recentMetrics = Array(self.recentMetrics.prefix(50))
                }
            }
            
            // Update cache
            cacheManager.cache(recentMetrics, forKey: "recent_metrics")
            
        } catch {
            DispatchQueue.main.async {
                self.error = .savingFailed(error.localizedDescription)
            }
        }
    }
    
    func saveTrainingSession(_ session: TrainingSession) async {
        do {
            let savedSession = try await networkManager.saveTrainingSession(session)
            
            // Update metrics with session data
            DispatchQueue.main.async {
                for jump in savedSession.jumps {
                    if !self.recentMetrics.contains(where: { $0.id == jump.id }) {
                        self.recentMetrics.insert(jump, at: 0)
                    }
                }
                
                // Sort by timestamp
                self.recentMetrics.sort { $0.timestamp > $1.timestamp }
            }
            
        } catch {
            DispatchQueue.main.async {
                self.error = .savingFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Video Processing
    private func processRecordedVideo(url: URL) {
        Task {
            do {
                // This would typically involve uploading the video and getting analysis results
                let analysisResult = try await networkManager.analyzeVideo(url: url)
                
                let jumpMetric = JumpMetric(
                    id: UUID().uuidString,
                    athleteId: UserDefaults.standard.string(forKey: "user_id") ?? "unknown",
                    timestamp: Date(),
                    jumpHeight: analysisResult.maxHeight,
                    contactTime: analysisResult.contactTime,
                    flightTime: analysisResult.flightTime,
                    takeoffVelocity: analysisResult.takeoffVelocity,
                    landingForce: analysisResult.landingForce,
                    symmetryScore: analysisResult.symmetryScore,
                    techniqueScore: analysisResult.techniqueScore,
                    videoURL: url.absoluteString,
                    poseData: []
                )
                
                await saveJumpMetric(jumpMetric)
                
            } catch {
                DispatchQueue.main.async {
                    self.error = .processingFailed(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Statistics Calculations
    func calculateStats(for metrics: [JumpMetric]) -> JumpStats {
        guard !metrics.isEmpty else {
            return JumpStats(
                totalJumps: 0,
                averageHeight: 0,
                bestHeight: 0,
                consistency: 0,
                averageSymmetry: 0,
                averageTechnique: 0,
                improvementRate: 0
            )
        }
        
        let totalJumps = metrics.count
        let averageHeight = metrics.map(\.jumpHeight).reduce(0, +) / Double(totalJumps)
        let bestHeight = metrics.max { $0.jumpHeight < $1.jumpHeight }?.jumpHeight ?? 0
        
        // Calculate consistency (inverse of standard deviation)
        let heights = metrics.map(\.jumpHeight)
        let variance = heights.map { pow($0 - averageHeight, 2) }.reduce(0, +) / Double(totalJumps)
        let standardDeviation = sqrt(variance)
        let consistency = max(0, 1.0 - (standardDeviation / averageHeight))
        
        let averageSymmetry = metrics.map(\.symmetryScore).reduce(0, +) / Double(totalJumps)
        let averageTechnique = metrics.map(\.techniqueScore).reduce(0, +) / Double(totalJumps)
        
        // Calculate improvement rate (linear regression slope)
        let improvementRate = calculateImprovementRate(metrics: metrics)
        
        return JumpStats(
            totalJumps: totalJumps,
            averageHeight: averageHeight,
            bestHeight: bestHeight,
            consistency: consistency,
            averageSymmetry: averageSymmetry,
            averageTechnique: averageTechnique,
            improvementRate: improvementRate
        )
    }
    
    private func calculateImprovementRate(metrics: [JumpMetric]) -> Double {
        guard metrics.count >= 2 else { return 0 }
        
        let sortedMetrics = metrics.sorted { $0.timestamp < $1.timestamp }
        let n = Double(sortedMetrics.count)
        
        // Simple linear regression to find slope
        let xValues = Array(0..<sortedMetrics.count).map(Double.init)
        let yValues = sortedMetrics.map(\.jumpHeight)
        
        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map(*).reduce(0, +)
        let sumXX = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        
        return slope
    }
    
    func getInsights(for metrics: [JumpMetric]) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []
        
        guard !metrics.isEmpty else { return insights }
        
        let stats = calculateStats(for: metrics)
        
        // Consistency insight
        if stats.consistency < 0.7 {
            insights.append(TrainingInsight(
                type: .consistency,
                title: "Improve Consistency",
                description: "Your jump heights vary significantly. Focus on developing muscle memory through repetition.",
                priority: .high,
                recommendations: [
                    "Practice with consistent form",
                    "Focus on timing and rhythm",
                    "Use video analysis for feedback"
                ]
            ))
        }
        
        // Technique insight
        if stats.averageTechnique < 0.7 {
            insights.append(TrainingInsight(
                type: .technique,
                title: "Technique Improvement",
                description: "Your jump technique has room for improvement.",
                priority: .high,
                recommendations: [
                    "Work on proper arm swing",
                    "Focus on knee bend timing",
                    "Practice landing mechanics"
                ]
            ))
        }
        
        // Symmetry insight
        if stats.averageSymmetry < 0.8 {
            insights.append(TrainingInsight(
                type: .symmetry,
                title: "Balance Training",
                description: "Your jumps show some asymmetry. Consider unilateral training.",
                priority: .medium,
                recommendations: [
                    "Single-leg exercises",
                    "Balance training",
                    "Address muscle imbalances"
                ]
            ))
        }
        
        // Progress insight
        if stats.improvementRate > 0.5 {
            insights.append(TrainingInsight(
                type: .progress,
                title: "Great Progress!",
                description: "You're showing consistent improvement in your jump height.",
                priority: .positive,
                recommendations: [
                    "Continue current training",
                    "Consider increasing intensity",
                    "Set new goals"
                ]
            ))
        } else if stats.improvementRate < -0.5 {
            insights.append(TrainingInsight(
                type: .progress,
                title: "Performance Decline",
                description: "Your performance has been declining. Consider rest or program adjustment.",
                priority: .high,
                recommendations: [
                    "Check for overtraining",
                    "Ensure adequate recovery",
                    "Review training program"
                ]
            ))
        }
        
        return insights
    }
    
    // MARK: - Cache Management
    private func loadCachedData() {
        if let cachedMetrics: [JumpMetric] = cacheManager.retrieve(forKey: "recent_metrics") {
            self.recentMetrics = cachedMetrics
        }
        
        if let cachedBest: JumpMetric = cacheManager.retrieve(forKey: "personal_best") {
            self.personalBest = cachedBest
        }
        
        if let cachedStats: WeeklyStats = cacheManager.retrieve(forKey: "weekly_stats") {
            self.weeklyStats = cachedStats
        }
    }
    
    func clearCache() {
        cacheManager.clearAll()
        
        DispatchQueue.main.async {
            self.recentMetrics = []
            self.personalBest = nil
            self.weeklyStats = nil
        }
    }
    
    // MARK: - Export Data
    func exportMetrics(format: ExportFormat) async -> URL? {
        do {
            let allMetrics = try await networkManager.fetchAllMetrics()
            return try await DataExporter.export(metrics: allMetrics, format: format)
        } catch {
            DispatchQueue.main.async {
                self.error = .exportFailed(error.localizedDescription)
            }
            return nil
        }
    }
}

// MARK: - Supporting Types
struct JumpStats {
    let totalJumps: Int
    let averageHeight: Double
    let bestHeight: Double
    let consistency: Double
    let averageSymmetry: Double
    let averageTechnique: Double
    let improvementRate: Double
}

struct WeeklyStats: Codable {
    let weekStart: Date
    let weekEnd: Date
    let totalJumps: Int
    let averageHeight: Double
    let bestJump: JumpMetric?
    let improvementFromLastWeek: Double
    let trainingDays: Int
    let totalTrainingTime: TimeInterval
}

struct TrainingInsight {
    let type: InsightType
    let title: String
    let description: String
    let priority: Priority
    let recommendations: [String]
    
    enum InsightType {
        case consistency, technique, symmetry, progress, frequency
    }
    
    enum Priority {
        case low, medium, high, positive
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .orange
            case .high: return .red
            case .positive: return .green
            }
        }
    }
}

enum TimePeriod: CaseIterable {
    case week, month, threeMonths, year, allTime
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        case .allTime: return Int.max
        }
    }
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        case .year: return "Year"
        case .allTime: return "All Time"
        }
    }
}

enum ExportFormat {
    case csv, json, pdf
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .pdf: return "pdf"
        }
    }
}

// MARK: - Metrics Error
enum MetricsError: LocalizedError {
    case loadingFailed(String)
    case savingFailed(String)
    case processingFailed(String)
    case exportFailed(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed(let message):
            return "Failed to load metrics: \(message)"
        case .savingFailed(let message):
            return "Failed to save metrics: \(message)"
        case .processingFailed(let message):
            return "Failed to process data: \(message)"
        case .exportFailed(let message):
            return "Failed to export data: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
} 