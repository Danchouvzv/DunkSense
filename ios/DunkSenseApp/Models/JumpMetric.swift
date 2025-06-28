import Foundation

// MARK: - Jump Metric Model
struct JumpMetric: Identifiable, Codable {
    let id: String
    let athleteId: String
    let timestamp: Date
    let jumpHeight: Double // in centimeters
    let contactTime: Double // in seconds
    let flightTime: Double // in seconds
    let takeoffVelocity: Double // in m/s
    let landingForce: Double // in Newtons
    let symmetryScore: Double // 0.0 to 1.0
    let techniqueScore: Double // 0.0 to 1.0
    let videoURL: String?
    let poseData: [PoseData]
    
    // Computed properties
    var jumpHeightInches: Double {
        return jumpHeight / 2.54
    }
    
    var jumpHeightFeet: String {
        let totalInches = jumpHeightInches
        let feet = Int(totalInches / 12)
        let inches = totalInches.truncatingRemainder(dividingBy: 12)
        return String(format: "%d'%.1f\"", feet, inches)
    }
    
    var powerScore: Double {
        // Calculate power score based on multiple factors
        let heightScore = min(jumpHeight / 80.0, 1.0) // Normalize to 80cm max
        let velocityScore = min(takeoffVelocity / 4.0, 1.0) // Normalize to 4 m/s max
        let techniqueWeight = 0.3
        let heightWeight = 0.4
        let velocityWeight = 0.3
        
        return (techniqueScore * techniqueWeight) + 
               (heightScore * heightWeight) + 
               (velocityScore * velocityWeight)
    }
    
    var overallScore: Double {
        return (powerScore + symmetryScore + techniqueScore) / 3.0
    }
    
    var grade: JumpGrade {
        switch overallScore {
        case 0.9...1.0:
            return .excellent
        case 0.8..<0.9:
            return .good
        case 0.7..<0.8:
            return .average
        case 0.6..<0.7:
            return .belowAverage
        default:
            return .poor
        }
    }
}

// MARK: - Jump Grade Enum
enum JumpGrade: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case average = "Average"
    case belowAverage = "Below Average"
    case poor = "Needs Work"
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .average:
            return "orange"
        case .belowAverage:
            return "yellow"
        case .poor:
            return "red"
        }
    }
    
    var emoji: String {
        switch self {
        case .excellent:
            return "🔥"
        case .good:
            return "👍"
        case .average:
            return "👌"
        case .belowAverage:
            return "⚠️"
        case .poor:
            return "📈"
        }
    }
}

// MARK: - Pose Data Model
struct PoseData: Codable {
    let timestamp: TimeInterval
    let keypoints: [String: Keypoint]
    let confidence: Double
    
    struct Keypoint: Codable {
        let location: CGPoint
        let confidence: Double
    }
}

// MARK: - Pose Connections
struct PoseConnections {
    static let humanPoseConnections: [(start: String, end: String)] = [
        // Head connections
        ("nose", "left_eye"),
        ("nose", "right_eye"),
        ("left_eye", "left_ear"),
        ("right_eye", "right_ear"),
        
        // Torso connections
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_elbow"),
        ("right_shoulder", "right_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_elbow", "right_wrist"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        
        // Leg connections
        ("left_hip", "left_knee"),
        ("right_hip", "right_knee"),
        ("left_knee", "left_ankle"),
        ("right_knee", "right_ankle")
    ]
}

// MARK: - Jump Analysis Result
struct JumpAnalysisResult {
    let maxHeight: Double
    let contactTime: Double
    let flightTime: Double
    let takeoffVelocity: Double
    let landingForce: Double
    let symmetryScore: Double
    let techniqueScore: Double
    let phases: [JumpPhase]
    let recommendations: [String]
}

// MARK: - Jump Phase
struct JumpPhase {
    let name: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let keyMetrics: [String: Double]
    
    enum PhaseType: String, CaseIterable {
        case preparation = "Preparation"
        case takeoff = "Takeoff"
        case flight = "Flight"
        case landing = "Landing"
    }
}

// MARK: - Training Session
struct TrainingSession: Identifiable, Codable {
    let id: String
    let athleteId: String
    let startTime: Date
    let endTime: Date
    let jumps: [JumpMetric]
    let notes: String?
    let location: String?
    let weather: String?
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    var averageHeight: Double {
        guard !jumps.isEmpty else { return 0 }
        return jumps.map(\.jumpHeight).reduce(0, +) / Double(jumps.count)
    }
    
    var bestJump: JumpMetric? {
        return jumps.max { $0.jumpHeight < $1.jumpHeight }
    }
    
    var totalJumps: Int {
        return jumps.count
    }
}

// MARK: - Athlete Profile
struct AthleteProfile: Identifiable, Codable {
    let id: String
    let userId: String
    let personalBest: Double?
    let totalJumps: Int
    let averageHeight: Double
    let consistencyScore: Double
    let strengthLevel: StrengthLevel
    let goals: [TrainingGoal]
    let achievements: [Achievement]
    let createdAt: Date
    let updatedAt: Date
    
    enum StrengthLevel: String, CaseIterable, Codable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case elite = "Elite"
        
        var minHeight: Double {
            switch self {
            case .beginner: return 0
            case .intermediate: return 40
            case .advanced: return 60
            case .elite: return 80
            }
        }
        
        var maxHeight: Double {
            switch self {
            case .beginner: return 40
            case .intermediate: return 60
            case .advanced: return 80
            case .elite: return 120
            }
        }
    }
}

// MARK: - Training Goal
struct TrainingGoal: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let deadline: Date?
    let isCompleted: Bool
    let createdAt: Date
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }
}

// MARK: - Achievement
struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let unlockedAt: Date?
    let requirements: [String]
    let category: AchievementCategory
    
    var isUnlocked: Bool {
        return unlockedAt != nil
    }
    
    enum AchievementCategory: String, CaseIterable, Codable {
        case height = "Height"
        case consistency = "Consistency"
        case technique = "Technique"
        case frequency = "Frequency"
        case milestone = "Milestone"
    }
}

// MARK: - Extensions
extension JumpMetric {
    static let mockData: [JumpMetric] = [
        JumpMetric(
            id: UUID().uuidString,
            athleteId: "user-1",
            timestamp: Date().addingTimeInterval(-86400 * 7),
            jumpHeight: 65.2,
            contactTime: 0.25,
            flightTime: 0.52,
            takeoffVelocity: 3.2,
            landingForce: 1200,
            symmetryScore: 0.85,
            techniqueScore: 0.78,
            videoURL: nil,
            poseData: []
        ),
        JumpMetric(
            id: UUID().uuidString,
            athleteId: "user-1",
            timestamp: Date().addingTimeInterval(-86400 * 6),
            jumpHeight: 67.8,
            contactTime: 0.23,
            flightTime: 0.55,
            takeoffVelocity: 3.4,
            landingForce: 1180,
            symmetryScore: 0.88,
            techniqueScore: 0.82,
            videoURL: nil,
            poseData: []
        ),
        JumpMetric(
            id: UUID().uuidString,
            athleteId: "user-1",
            timestamp: Date().addingTimeInterval(-86400 * 5),
            jumpHeight: 63.1,
            contactTime: 0.27,
            flightTime: 0.49,
            takeoffVelocity: 3.0,
            landingForce: 1250,
            symmetryScore: 0.82,
            techniqueScore: 0.75,
            videoURL: nil,
            poseData: []
        ),
        JumpMetric(
            id: UUID().uuidString,
            athleteId: "user-1",
            timestamp: Date().addingTimeInterval(-86400 * 4),
            jumpHeight: 69.5,
            contactTime: 0.22,
            flightTime: 0.58,
            takeoffVelocity: 3.6,
            landingForce: 1150,
            symmetryScore: 0.90,
            techniqueScore: 0.85,
            videoURL: nil,
            poseData: []
        ),
        JumpMetric(
            id: UUID().uuidString,
            athleteId: "user-1",
            timestamp: Date().addingTimeInterval(-86400 * 3),
            jumpHeight: 66.7,
            contactTime: 0.24,
            flightTime: 0.53,
            takeoffVelocity: 3.3,
            landingForce: 1190,
            symmetryScore: 0.86,
            techniqueScore: 0.80,
            videoURL: nil,
            poseData: []
        )
    ]
} 