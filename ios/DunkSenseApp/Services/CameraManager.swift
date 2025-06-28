import AVFoundation
import SwiftUI
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: CameraError?
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var outputURL: URL?
    
    // Delegates
    weak var videoDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    weak var audioDelegate: AVCaptureAudioDataOutputSampleBufferDelegate?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoDataOutputQueue = DispatchQueue(label: "camera.video.queue")
    private let audioDataOutputQueue = DispatchQueue(label: "camera.audio.queue")
    
    override init() {
        super.init()
        checkCameraPermissions()
    }
    
    // MARK: - Permission Management
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if granted {
                        self.setupCaptureSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.error = .permissionDenied
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Session Setup
    private func setupCaptureSession() {
        sessionQueue.async {
            self.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        guard captureSession == nil else { return }
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // Configure video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                       for: .video, 
                                                       position: currentCameraPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            DispatchQueue.main.async {
                self.error = .deviceNotFound
            }
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            self.videoInput = videoInput
        }
        
        // Configure audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                self.audioInput = audioInput
            }
        }
        
        // Configure video output for real-time processing
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
        
        // Configure movie file output for recording
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            self.movieFileOutput = movieOutput
        }
        
        // Configure preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        DispatchQueue.main.async {
            self.previewLayer = previewLayer
            self.captureSession = session
        }
        
        session.startRunning()
    }
    
    // MARK: - Camera Controls
    func startSession() {
        sessionQueue.async {
            guard let session = self.captureSession, !session.isRunning else { return }
            session.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            guard let session = self.captureSession, session.isRunning else { return }
            session.stopRunning()
        }
    }
    
    func switchCamera() {
        sessionQueue.async {
            guard let session = self.captureSession else { return }
            
            session.beginConfiguration()
            
            // Remove current video input
            if let currentInput = self.videoInput {
                session.removeInput(currentInput)
            }
            
            // Switch camera position
            let newPosition: AVCaptureDevice.Position = self.currentCameraPosition == .back ? .front : .back
            
            // Add new video input
            guard let newVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                              for: .video,
                                                              position: newPosition),
                  let newVideoInput = try? AVCaptureDeviceInput(device: newVideoDevice) else {
                session.commitConfiguration()
                return
            }
            
            if session.canAddInput(newVideoInput) {
                session.addInput(newVideoInput)
                self.videoInput = newVideoInput
                
                DispatchQueue.main.async {
                    self.currentCameraPosition = newPosition
                }
            }
            
            session.commitConfiguration()
        }
    }
    
    // MARK: - Recording Controls
    func startRecording() {
        guard let movieOutput = movieFileOutput, !movieOutput.isRecording else { return }
        
        let outputURL = createOutputURL()
        self.outputURL = outputURL
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        
        recordingStartTime = Date()
        startRecordingTimer()
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    func stopRecording() {
        guard let movieOutput = movieFileOutput, movieOutput.isRecording else { return }
        
        movieOutput.stopRecording()
        stopRecordingTimer()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingDuration = 0
        }
    }
    
    private func createOutputURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask)[0]
        let fileName = "jump_\(Date().timeIntervalSince1970).mov"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let startTime = self.recordingStartTime else { return }
            let duration = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                self.recordingDuration = duration
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }
    
    // MARK: - Camera Settings
    func setFocusMode(_ mode: AVCaptureDevice.FocusMode) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else { return }
            
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(mode) {
                    device.focusMode = mode
                }
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.error = .configurationFailed
                }
            }
        }
    }
    
    func setExposureMode(_ mode: AVCaptureDevice.ExposureMode) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else { return }
            
            do {
                try device.lockForConfiguration()
                if device.isExposureModeSupported(mode) {
                    device.exposureMode = mode
                }
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.error = .configurationFailed
                }
            }
        }
    }
    
    func setFrameRate(_ frameRate: Double) {
        sessionQueue.async {
            guard let device = self.videoInput?.device else { return }
            
            do {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.error = .configurationFailed
                }
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        stopSession()
        stopRecordingTimer()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, 
                      didOutput sampleBuffer: CMSampleBuffer, 
                      from connection: AVCaptureConnection) {
        // Forward to registered delegate
        videoDelegate?.captureOutput(output, didOutput: sampleBuffer, from: connection)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, 
                   didStartRecordingTo fileURL: URL, 
                   from connections: [AVCaptureConnection]) {
        print("Recording started to: \(fileURL)")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, 
                   didFinishRecordingTo outputFileURL: URL, 
                   from connections: [AVCaptureConnection], 
                   error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.error = .recordingFailed(error.localizedDescription)
            }
        } else {
            // Notify that recording is complete with the file URL
            NotificationCenter.default.post(
                name: .recordingCompleted,
                object: nil,
                userInfo: ["fileURL": outputFileURL]
            )
        }
    }
}

// MARK: - Camera Error
enum CameraError: LocalizedError {
    case permissionDenied
    case deviceNotFound
    case configurationFailed
    case recordingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied. Please enable camera access in Settings."
        case .deviceNotFound:
            return "Camera device not found."
        case .configurationFailed:
            return "Failed to configure camera."
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let recordingCompleted = Notification.Name("recordingCompleted")
}

// MARK: - Camera Preview UIViewRepresentable
struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            self.previewLayer.frame = uiView.bounds
        }
    }
} 