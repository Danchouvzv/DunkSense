import SwiftUI
import AVFoundation
import CoreML
import Vision

@main
struct DunkSenseApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var poseEstimator = PoseEstimationService()
    @StateObject private var metricsManager = MetricsManager()
    
    init() {
        setupApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(cameraManager)
                .environmentObject(poseEstimator)
                .environmentObject(metricsManager)
                .onAppear {
                    requestPermissions()
                }
        }
    }
    
    private func setupApp() {
        // Configure app appearance
        configureAppearance()
        
        // Setup Core ML
        setupCoreML()
        
        // Setup networking
        setupNetworking()
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    private func setupCoreML() {
        // Warm up Core ML models
        Task {
            await poseEstimator.loadModel()
        }
    }
    
    private func setupNetworking() {
        // Configure networking stack
        NetworkManager.shared.configure()
    }
    
    private func requestPermissions() {
        // Request camera permission
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                appState.cameraPermissionGranted = granted
            }
        }
        
        // Request microphone permission (for video recording)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                appState.microphonePermissionGranted = granted
            }
        }
        
        // Request motion permission
        appState.requestMotionPermission()
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var isOnboardingCompleted: Bool = false
    @Published var isUserLoggedIn: Bool = false
    @Published var cameraPermissionGranted: Bool = false
    @Published var microphonePermissionGranted: Bool = false
    @Published var motionPermissionGranted: Bool = false
    
    @Published var currentUser: User?
    @Published var selectedTab: Tab = .home
    
    enum Tab: String, CaseIterable {
        case home = "Home"
        case capture = "Capture"
        case progress = "Progress"
        case community = "Community"
        case profile = "Profile"
        
        var iconName: String {
            switch self {
            case .home: return "house.fill"
            case .capture: return "camera.fill"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .community: return "person.3.fill"
            case .profile: return "person.crop.circle.fill"
            }
        }
    }
    
    init() {
        loadUserDefaults()
        checkAuthenticationStatus()
    }
    
    private func loadUserDefaults() {
        isOnboardingCompleted = UserDefaults.standard.bool(forKey: "onboarding_completed")
        isUserLoggedIn = UserDefaults.standard.bool(forKey: "user_logged_in")
    }
    
    private func checkAuthenticationStatus() {
        // Check if user has valid authentication token
        if let token = AuthManager.shared.getCurrentToken(), !token.isEmpty {
            isUserLoggedIn = true
            loadCurrentUser()
        }
    }
    
    private func loadCurrentUser() {
        Task {
            do {
                let user = try await AuthManager.shared.getCurrentUser()
                await MainActor.run {
                    self.currentUser = user
                }
            } catch {
                print("Failed to load current user: \(error)")
                await MainActor.run {
                    self.isUserLoggedIn = false
                }
            }
        }
    }
    
    func completeOnboarding() {
        isOnboardingCompleted = true
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
    }
    
    func login(user: User) {
        currentUser = user
        isUserLoggedIn = true
        UserDefaults.standard.set(true, forKey: "user_logged_in")
    }
    
    func logout() {
        currentUser = nil
        isUserLoggedIn = false
        UserDefaults.standard.set(false, forKey: "user_logged_in")
        AuthManager.shared.clearToken()
    }
    
    func requestMotionPermission() {
        // Request Core Motion permission if needed
        // This is handled automatically when accessing motion data
        motionPermissionGranted = true
    }
}

// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let avatarURL: String?
    let createdAt: Date
    
    // Athletic profile
    let age: Int?
    let height: Int? // in cm
    let weight: Double? // in kg
    let sportLevel: SportLevel
    let goals: [String]
    
    enum SportLevel: String, Codable, CaseIterable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
        case professional = "professional"
        
        var displayName: String {
            switch self {
            case .beginner: return "Beginner"
            case .intermediate: return "Intermediate"
            case .advanced: return "Advanced"
            case .professional: return "Professional"
            }
        }
    }
} 