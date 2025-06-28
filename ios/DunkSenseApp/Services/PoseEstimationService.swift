import Vision
import CoreML
import AVFoundation
import SwiftUI
import Combine

class PoseEstimationService: NSObject, ObservableObject {
    @Published var currentPose: VNHumanBodyPoseObservation?
    @Published var isProcessing = false
    @Published var confidence: Double = 0.0
    @Published var error: PoseEstimationError?
    @Published var jumpPhase: JumpPhase.PhaseType = .preparation
    
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    private var sequenceHandler = VNSequenceRequestHandler()
    
    // Jump analysis properties
    private var poseHistory: [TimestampedPose] = []
    private var jumpStartTime: TimeInterval?
    private var isAnalyzingJump = false
    private var maxHeightReached = false
    private var landingDetected = false
    
    // Analysis parameters
    private let minJumpHeight: Double = 10.0 // cm
    private let maxPoseHistorySize = 300 // ~10 seconds at 30fps
    private let jumpDetectionThreshold: Double = 0.15 // velocity threshold
    
    private struct TimestampedPose {
        let pose: VNHumanBodyPoseObservation
        let timestamp: TimeInterval
        let hipHeight: Double
        let velocity: Double
    }
    
    override init() {
        super.init()
        setupPoseDetection()
    }
    
    // MARK: - Setup
    private func setupPoseDetection() {
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            self?.handlePoseDetection(request: request, error: error)
        }
        
        request.revision = VNDetectHumanBodyPoseRequestRevision1
        self.poseRequest = request
    }
    
    // MARK: - Pose Detection
    func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let poseRequest = poseRequest else { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        
        do {
            try sequenceHandler.perform([poseRequest], on: sampleBuffer)
        } catch {
            DispatchQueue.main.async {
                self.error = .processingFailed(error.localizedDescription)
            }
        }
    }
    
    private func handlePoseDetection(request: VNRequest, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.error = .processingFailed(error.localizedDescription)
            }
            return
        }
        
        guard let observations = request.results as? [VNHumanBodyPoseObservation],
              let pose = observations.first else {
            return
        }
        
        let timestamp = Date().timeIntervalSince1970
        
        DispatchQueue.main.async {
            self.currentPose = pose
            self.confidence = Double(pose.confidence)
        }
        
        // Analyze pose for jump detection
        if isAnalyzingJump {
            analyzePoseForJump(pose: pose, timestamp: timestamp)
        }
    }
    
    // MARK: - Jump Analysis
    func startJumpAnalysis() {
        isAnalyzingJump = true
        poseHistory.removeAll()
        jumpStartTime = nil
        maxHeightReached = false
        landingDetected = false
        
        DispatchQueue.main.async {
            self.jumpPhase = .preparation
        }
    }
    
    func stopJumpAnalysis() -> JumpAnalysisResult? {
        isAnalyzingJump = false
        
        guard poseHistory.count > 10 else {
            return nil
        }
        
        return analyzeJumpSequence()
    }
    
    private func analyzePoseForJump(pose: VNHumanBodyPoseObservation, timestamp: TimeInterval) {
        guard let hipHeight = calculateHipHeight(from: pose) else { return }
        
        let velocity = calculateVerticalVelocity(hipHeight: hipHeight, timestamp: timestamp)
        
        let timestampedPose = TimestampedPose(
            pose: pose,
            timestamp: timestamp,
            hipHeight: hipHeight,
            velocity: velocity
        )
        
        poseHistory.append(timestampedPose)
        
        // Limit history size
        if poseHistory.count > maxPoseHistorySize {
            poseHistory.removeFirst()
        }
        
        // Detect jump phases
        detectJumpPhase(currentPose: timestampedPose)
    }
    
    private func calculateHipHeight(from pose: VNHumanBodyPoseObservation) -> Double? {
        do {
            let leftHip = try pose.recognizedPoint(.leftHip)
            let rightHip = try pose.recognizedPoint(.rightHip)
            
            guard leftHip.confidence > 0.3 && rightHip.confidence > 0.3 else {
                return nil
            }
            
            let avgHipY = (leftHip.location.y + rightHip.location.y) / 2
            
            // Convert normalized coordinates to estimated height in cm
            // This is a simplified conversion - in practice, you'd need camera calibration
            let estimatedHeight = Double(1.0 - avgHipY) * 200.0 // Assume 200cm frame height
            
            return estimatedHeight
        } catch {
            return nil
        }
    }
    
    private func calculateVerticalVelocity(hipHeight: Double, timestamp: TimeInterval) -> Double {
        guard poseHistory.count >= 2 else { return 0.0 }
        
        let previousPose = poseHistory[poseHistory.count - 2]
        let timeDelta = timestamp - previousPose.timestamp
        
        guard timeDelta > 0 else { return 0.0 }
        
        let heightDelta = hipHeight - previousPose.hipHeight
        return heightDelta / timeDelta
    }
    
    private func detectJumpPhase(currentPose: TimestampedPose) {
        let velocity = currentPose.velocity
        
        switch jumpPhase {
        case .preparation:
            // Detect takeoff when upward velocity exceeds threshold
            if velocity > jumpDetectionThreshold {
                jumpStartTime = currentPose.timestamp
                DispatchQueue.main.async {
                    self.jumpPhase = .takeoff
                }
            }
            
        case .takeoff:
            // Detect flight when velocity becomes negative (apex reached)
            if velocity < -jumpDetectionThreshold {
                maxHeightReached = true
                DispatchQueue.main.async {
                    self.jumpPhase = .flight
                }
            }
            
        case .flight:
            // Detect landing when downward velocity decreases significantly
            if maxHeightReached && abs(velocity) < jumpDetectionThreshold {
                landingDetected = true
                DispatchQueue.main.async {
                    self.jumpPhase = .landing
                }
            }
            
        case .landing:
            // Jump analysis complete
            break
        }
    }
    
    private func analyzeJumpSequence() -> JumpAnalysisResult {
        let maxHeight = poseHistory.max { $0.hipHeight < $1.hipHeight }?.hipHeight ?? 0
        let minHeight = poseHistory.min { $0.hipHeight < $1.hipHeight }?.hipHeight ?? 0
        let jumpHeight = maxHeight - minHeight
        
        // Calculate flight time
        let takeoffPoses = poseHistory.filter { $0.velocity > jumpDetectionThreshold }
        let landingPoses = poseHistory.filter { $0.velocity < -jumpDetectionThreshold }
        
        let flightTime = calculateFlightTime()
        let contactTime = calculateContactTime()
        let takeoffVelocity = calculateTakeoffVelocity()
        let landingForce = calculateLandingForce()
        let symmetryScore = calculateSymmetryScore()
        let techniqueScore = calculateTechniqueScore()
        
        let phases = analyzeJumpPhases()
        let recommendations = generateRecommendations(
            jumpHeight: jumpHeight,
            symmetryScore: symmetryScore,
            techniqueScore: techniqueScore
        )
        
        return JumpAnalysisResult(
            maxHeight: jumpHeight,
            contactTime: contactTime,
            flightTime: flightTime,
            takeoffVelocity: takeoffVelocity,
            landingForce: landingForce,
            symmetryScore: symmetryScore,
            techniqueScore: techniqueScore,
            phases: phases,
            recommendations: recommendations
        )
    }
    
    private func calculateFlightTime() -> Double {
        guard let startTime = jumpStartTime else { return 0 }
        
        let landingTime = poseHistory.last { $0.velocity < -jumpDetectionThreshold }?.timestamp ?? startTime
        return landingTime - startTime
    }
    
    private func calculateContactTime() -> Double {
        // Simplified contact time calculation
        // In practice, this would require force plate data or more sophisticated analysis
        return 0.25 // Average contact time in seconds
    }
    
    private func calculateTakeoffVelocity() -> Double {
        let takeoffPoses = poseHistory.filter { $0.velocity > jumpDetectionThreshold }
        let maxVelocity = takeoffPoses.max { $0.velocity < $1.velocity }?.velocity ?? 0
        
        // Convert to m/s (rough approximation)
        return maxVelocity / 100.0
    }
    
    private func calculateLandingForce() -> Double {
        // Simplified landing force calculation
        // In practice, this would require more sophisticated biomechanical analysis
        let landingVelocity = poseHistory.filter { $0.velocity < -jumpDetectionThreshold }
            .max { abs($0.velocity) < abs($1.velocity) }?.velocity ?? 0
        
        // Rough estimation based on velocity (would need body weight and other factors)
        return abs(landingVelocity) * 1000 // Simplified force calculation
    }
    
    private func calculateSymmetryScore() -> Double {
        var symmetryScores: [Double] = []
        
        for pose in poseHistory {
            if let score = calculatePoseSymmetry(pose.pose) {
                symmetryScores.append(score)
            }
        }
        
        guard !symmetryScores.isEmpty else { return 0.5 }
        
        return symmetryScores.reduce(0, +) / Double(symmetryScores.count)
    }
    
    private func calculatePoseSymmetry(_ pose: VNHumanBodyPoseObservation) -> Double? {
        do {
            let leftShoulder = try pose.recognizedPoint(.leftShoulder)
            let rightShoulder = try pose.recognizedPoint(.rightShoulder)
            let leftHip = try pose.recognizedPoint(.leftHip)
            let rightHip = try pose.recognizedPoint(.rightHip)
            let leftKnee = try pose.recognizedPoint(.leftKnee)
            let rightKnee = try pose.recognizedPoint(.rightKnee)
            
            guard leftShoulder.confidence > 0.3 && rightShoulder.confidence > 0.3 &&
                  leftHip.confidence > 0.3 && rightHip.confidence > 0.3 &&
                  leftKnee.confidence > 0.3 && rightKnee.confidence > 0.3 else {
                return nil
            }
            
            // Calculate symmetry based on joint positions
            let shoulderSymmetry = 1.0 - abs(leftShoulder.location.y - rightShoulder.location.y)
            let hipSymmetry = 1.0 - abs(leftHip.location.y - rightHip.location.y)
            let kneeSymmetry = 1.0 - abs(leftKnee.location.y - rightKnee.location.y)
            
            return (shoulderSymmetry + hipSymmetry + kneeSymmetry) / 3.0
            
        } catch {
            return nil
        }
    }
    
    private func calculateTechniqueScore() -> Double {
        var techniqueScores: [Double] = []
        
        for pose in poseHistory {
            if let score = calculatePoseTechnique(pose.pose) {
                techniqueScores.append(score)
            }
        }
        
        guard !techniqueScores.isEmpty else { return 0.5 }
        
        return techniqueScores.reduce(0, +) / Double(techniqueScores.count)
    }
    
    private func calculatePoseTechnique(_ pose: VNHumanBodyPoseObservation) -> Double? {
        do {
            let leftKnee = try pose.recognizedPoint(.leftKnee)
            let rightKnee = try pose.recognizedPoint(.rightKnee)
            let leftAnkle = try pose.recognizedPoint(.leftAnkle)
            let rightAnkle = try pose.recognizedPoint(.rightAnkle)
            
            guard leftKnee.confidence > 0.3 && rightKnee.confidence > 0.3 &&
                  leftAnkle.confidence > 0.3 && rightAnkle.confidence > 0.3 else {
                return nil
            }
            
            // Calculate knee bend angle (simplified)
            let leftKneeBend = abs(leftKnee.location.y - leftAnkle.location.y)
            let rightKneeBend = abs(rightKnee.location.y - rightAnkle.location.y)
            
            // Good technique has appropriate knee bend
            let avgKneeBend = (leftKneeBend + rightKneeBend) / 2.0
            
            // Score based on optimal knee bend (around 0.1-0.2 normalized units)
            let optimalBend = 0.15
            let bendScore = 1.0 - abs(avgKneeBend - optimalBend) / optimalBend
            
            return max(0.0, min(1.0, bendScore))
            
        } catch {
            return nil
        }
    }
    
    private func analyzeJumpPhases() -> [JumpPhase] {
        var phases: [JumpPhase] = []
        
        // Preparation phase
        let prepPhases = poseHistory.prefix(while: { $0.velocity <= jumpDetectionThreshold })
        if !prepPhases.isEmpty {
            phases.append(JumpPhase(
                name: "Preparation",
                startTime: prepPhases.first?.timestamp ?? 0,
                endTime: prepPhases.last?.timestamp ?? 0,
                keyMetrics: ["avgHeight": prepPhases.map(\.hipHeight).reduce(0, +) / Double(prepPhases.count)]
            ))
        }
        
        // Takeoff phase
        let takeoffPhases = poseHistory.filter { $0.velocity > jumpDetectionThreshold }
        if !takeoffPhases.isEmpty {
            phases.append(JumpPhase(
                name: "Takeoff",
                startTime: takeoffPhases.first?.timestamp ?? 0,
                endTime: takeoffPhases.last?.timestamp ?? 0,
                keyMetrics: [
                    "maxVelocity": takeoffPhases.max { $0.velocity < $1.velocity }?.velocity ?? 0,
                    "avgVelocity": takeoffPhases.map(\.velocity).reduce(0, +) / Double(takeoffPhases.count)
                ]
            ))
        }
        
        // Flight phase
        let flightPhases = poseHistory.filter { abs($0.velocity) < jumpDetectionThreshold && maxHeightReached }
        if !flightPhases.isEmpty {
            phases.append(JumpPhase(
                name: "Flight",
                startTime: flightPhases.first?.timestamp ?? 0,
                endTime: flightPhases.last?.timestamp ?? 0,
                keyMetrics: [
                    "maxHeight": flightPhases.max { $0.hipHeight < $1.hipHeight }?.hipHeight ?? 0,
                    "duration": (flightPhases.last?.timestamp ?? 0) - (flightPhases.first?.timestamp ?? 0)
                ]
            ))
        }
        
        // Landing phase
        let landingPhases = poseHistory.suffix(while: { $0.velocity < -jumpDetectionThreshold })
        if !landingPhases.isEmpty {
            phases.append(JumpPhase(
                name: "Landing",
                startTime: landingPhases.first?.timestamp ?? 0,
                endTime: landingPhases.last?.timestamp ?? 0,
                keyMetrics: [
                    "minVelocity": landingPhases.min { $0.velocity < $1.velocity }?.velocity ?? 0,
                    "impactForce": abs(landingPhases.min { $0.velocity < $1.velocity }?.velocity ?? 0) * 1000
                ]
            ))
        }
        
        return phases
    }
    
    private func generateRecommendations(jumpHeight: Double, symmetryScore: Double, techniqueScore: Double) -> [String] {
        var recommendations: [String] = []
        
        if jumpHeight < 30 {
            recommendations.append("Focus on explosive power training to increase jump height")
            recommendations.append("Work on plyometric exercises like box jumps and depth jumps")
        }
        
        if symmetryScore < 0.7 {
            recommendations.append("Improve body symmetry with unilateral strength training")
            recommendations.append("Focus on single-leg exercises to balance left-right differences")
        }
        
        if techniqueScore < 0.7 {
            recommendations.append("Work on jump technique - focus on proper knee bend and arm swing")
            recommendations.append("Practice landing mechanics to improve efficiency")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Great technique! Continue with your current training program")
            recommendations.append("Consider increasing training intensity for further improvements")
        }
        
        return recommendations
    }
    
    // MARK: - Utility Methods
    func getPoseKeypoints() -> [String: CGPoint] {
        guard let pose = currentPose else { return [:] }
        
        var keypoints: [String: CGPoint] = [:]
        
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .leftEye, .rightEye, .leftEar, .rightEar,
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        for jointName in jointNames {
            do {
                let point = try pose.recognizedPoint(jointName)
                if point.confidence > 0.3 {
                    keypoints[jointName.rawValue] = point.location
                }
            } catch {
                continue
            }
        }
        
        return keypoints
    }
}

// MARK: - Pose Estimation Error
enum PoseEstimationError: LocalizedError {
    case modelLoadFailed
    case processingFailed(String)
    case invalidInput
    
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load pose estimation model"
        case .processingFailed(let message):
            return "Pose processing failed: \(message)"
        case .invalidInput:
            return "Invalid input for pose estimation"
        }
    }
}