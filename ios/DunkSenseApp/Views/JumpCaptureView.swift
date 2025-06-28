import SwiftUI
import AVFoundation
import Vision

struct JumpCaptureView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var poseEstimationService: PoseEstimationService
    @EnvironmentObject var metricsManager: MetricsManager
    
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var showingResults = false
    @State private var lastJumpMetric: JumpMetric?
    @State private var showingSettings = false
    @State private var recordingState: RecordingState = .idle
    
    enum RecordingState {
        case idle
        case preparing
        case recording
        case processing
        case completed
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                // Overlay UI
                VStack {
                    // Top controls
                    topControls
                    
                    Spacer()
                    
                    // Pose overlay
                    if poseEstimationService.isTracking {
                        PoseOverlayView(poses: poseEstimationService.currentPoses)
                    }
                    
                    Spacer()
                    
                    // Bottom controls
                    bottomControls
                }
                
                // Recording indicator
                if recordingState == .recording {
                    recordingIndicator
                }
                
                // Processing overlay
                if recordingState == .processing {
                    processingOverlay
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupCamera()
            }
            .onDisappear {
                stopRecording()
            }
            .sheet(isPresented: $showingResults) {
                if let metric = lastJumpMetric {
                    JumpResultsView(metric: metric)
                }
            }
            .sheet(isPresented: $showingSettings) {
                CameraSettingsView()
            }
        }
    }
    
    private var topControls: some View {
        HStack {
            // Settings button
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Recording status
            VStack(spacing: 4) {
                Text(recordingState.displayText)
                    .font(.headline)
                    .foregroundColor(.white)
                
                if recordingState == .recording {
                    Text(formatDuration(recordingDuration))
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            
            Spacer()
            
            // Close button
            Button(action: {
                appState.selectedTab = .home
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Instructions
            if recordingState == .idle {
                VStack(spacing: 8) {
                    Text("Position yourself in frame")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Stand 2-3 meters from camera • Ensure good lighting")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
            }
            
            // Recording controls
            HStack(spacing: 30) {
                // Gallery button
                Button(action: {
                    // Open gallery/history
                }) {
                    Image(systemName: "photo.stack")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .disabled(recordingState != .idle)
                
                // Main record button
                Button(action: {
                    toggleRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(recordButtonColor)
                            .frame(width: 80, height: 80)
                        
                        if recordingState == .recording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                        }
                    }
                }
                .disabled(recordingState == .processing)
                .scaleEffect(isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isRecording)
                
                // Switch camera button
                Button(action: {
                    cameraManager.switchCamera()
                }) {
                    Image(systemName: "camera.rotate")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .disabled(recordingState != .idle)
            }
            .padding(.bottom, 50)
        }
    }
    
    private var recordingIndicator: some View {
        VStack {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .opacity(0.8)
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: recordingDuration)
                
                Text("REC")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Spacer()
            }
            .padding()
            
            Spacer()
        }
    }
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Analyzing Jump...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Our AI is processing your movement data")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    private var recordButtonColor: Color {
        switch recordingState {
        case .idle:
            return .red
        case .preparing:
            return .orange
        case .recording:
            return .red
        case .processing:
            return .gray
        case .completed:
            return .green
        }
    }
    
    private func setupCamera() {
        Task {
            await cameraManager.requestPermission()
            if cameraManager.hasPermission {
                await cameraManager.startSession()
                await poseEstimationService.startTracking()
            }
        }
    }
    
    private func toggleRecording() {
        if recordingState == .idle {
            startRecording()
        } else if recordingState == .recording {
            stopRecording()
        }
    }
    
    private func startRecording() {
        guard recordingState == .idle else { return }
        
        recordingState = .preparing
        
        // Brief delay for user preparation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            recordingState = .recording
            isRecording = true
            recordingDuration = 0
            
            // Start recording timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration += 0.1
                
                // Auto-stop after 10 seconds
                if recordingDuration >= 10.0 {
                    stopRecording()
                }
            }
            
            // Start actual recording
            Task {
                await cameraManager.startRecording()
                await poseEstimationService.startRecording()
            }
        }
    }
    
    private func stopRecording() {
        guard recordingState == .recording else { return }
        
        recordingState = .processing
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        Task {
            do {
                // Stop recording
                let videoURL = await cameraManager.stopRecording()
                let poseData = await poseEstimationService.stopRecording()
                
                // Process the jump
                let metric = try await processJump(videoURL: videoURL, poseData: poseData)
                
                // Save metric
                try await metricsManager.saveMetric(metric)
                
                await MainActor.run {
                    lastJumpMetric = metric
                    recordingState = .completed
                    showingResults = true
                    
                    // Reset state after showing results
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        recordingState = .idle
                    }
                }
                
            } catch {
                print("Failed to process jump: \(error)")
                await MainActor.run {
                    recordingState = .idle
                }
            }
        }
    }
    
    private func processJump(videoURL: URL?, poseData: [PoseData]) async throws -> JumpMetric {
        // Analyze the pose data to extract jump metrics
        let analyzer = JumpAnalyzer()
        let analysis = try await analyzer.analyze(poseData: poseData)
        
        return JumpMetric(
            id: UUID().uuidString,
            athleteId: appState.currentUser?.id ?? "unknown",
            timestamp: Date(),
            jumpHeight: analysis.maxHeight,
            contactTime: analysis.contactTime,
            flightTime: analysis.flightTime,
            takeoffVelocity: analysis.takeoffVelocity,
            landingForce: analysis.landingForce,
            symmetryScore: analysis.symmetryScore,
            techniqueScore: analysis.techniqueScore,
            videoURL: videoURL?.absoluteString,
            poseData: poseData
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

// MARK: - Recording State Extension
extension JumpCaptureView.RecordingState {
    var displayText: String {
        switch self {
        case .idle:
            return "Ready to Record"
        case .preparing:
            return "Get Ready..."
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .completed:
            return "Complete"
        }
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Pose Overlay
struct PoseOverlayView: View {
    let poses: [PoseData]
    
    var body: some View {
        Canvas { context, size in
            for pose in poses {
                drawPose(pose, in: context, size: size)
            }
        }
    }
    
    private func drawPose(_ pose: PoseData, in context: GraphicsContext, size: CGSize) {
        // Draw pose keypoints and connections
        let keypoints = pose.keypoints
        
        // Draw connections between keypoints
        let connections = PoseConnections.humanPoseConnections
        for connection in connections {
            if let startPoint = keypoints[connection.start],
               let endPoint = keypoints[connection.end],
               startPoint.confidence > 0.5 && endPoint.confidence > 0.5 {
                
                let start = CGPoint(
                    x: startPoint.location.x * size.width,
                    y: startPoint.location.y * size.height
                )
                let end = CGPoint(
                    x: endPoint.location.x * size.width,
                    y: endPoint.location.y * size.height
                )
                
                context.stroke(
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    },
                    with: .color(.green),
                    lineWidth: 2
                )
            }
        }
        
        // Draw keypoints
        for keypoint in keypoints.values {
            if keypoint.confidence > 0.5 {
                let point = CGPoint(
                    x: keypoint.location.x * size.width,
                    y: keypoint.location.y * size.height
                )
                
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - 3,
                        y: point.y - 3,
                        width: 6,
                        height: 6
                    )),
                    with: .color(.green)
                )
            }
        }
    }
}

#Preview {
    JumpCaptureView()
        .environmentObject(AppState())
        .environmentObject(CameraManager())
        .environmentObject(PoseEstimationService())
        .environmentObject(MetricsManager())
} 