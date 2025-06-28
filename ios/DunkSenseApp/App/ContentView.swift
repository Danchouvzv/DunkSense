import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if !appState.isOnboardingCompleted {
                OnboardingView()
            } else if !appState.isUserLoggedIn {
                AuthenticationView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isOnboardingCompleted)
        .animation(.easeInOut(duration: 0.3), value: appState.isUserLoggedIn)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: AppState.Tab.home.iconName)
                    Text(AppState.Tab.home.rawValue)
                }
                .tag(AppState.Tab.home)
            
            JumpCaptureView()
                .tabItem {
                    Image(systemName: AppState.Tab.capture.iconName)
                    Text(AppState.Tab.capture.rawValue)
                }
                .tag(AppState.Tab.capture)
            
            ProgressView()
                .tabItem {
                    Image(systemName: AppState.Tab.progress.iconName)
                    Text(AppState.Tab.progress.rawValue)
                }
                .tag(AppState.Tab.progress)
            
            CommunityView()
                .tabItem {
                    Image(systemName: AppState.Tab.community.iconName)
                    Text(AppState.Tab.community.rawValue)
                }
                .tag(AppState.Tab.community)
            
            ProfileView()
                .tabItem {
                    Image(systemName: AppState.Tab.profile.iconName)
                    Text(AppState.Tab.profile.rawValue)
                }
                .tag(AppState.Tab.profile)
        }
        .accentColor(.primary)
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    
    private let onboardingPages = [
        OnboardingPage(
            title: "Welcome to DunkSense AI",
            subtitle: "Transform your iPhone into a personal biomechanical coach",
            imageName: "basketball",
            description: "Use your camera and LiDAR to track jump technique and get AI-powered training recommendations."
        ),
        OnboardingPage(
            title: "Precise Jump Analysis",
            subtitle: "Measure your vertical jump with ±1.5cm accuracy",
            imageName: "ruler",
            description: "Our Core ML models analyze your jump height, contact time, and biomechanics in real-time."
        ),
        OnboardingPage(
            title: "Personalized Training",
            subtitle: "Get AI-generated workout plans tailored to your goals",
            imageName: "figure.strengthtraining.traditional",
            description: "Based on your performance data, receive custom training programs to maximize your vertical jump."
        ),
        OnboardingPage(
            title: "Track Your Progress",
            subtitle: "Monitor improvements and prevent injuries",
            imageName: "chart.line.uptrend.xyaxis",
            description: "Visualize your progress over time and get alerts about potential injury risks."
        )
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    OnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            Button(action: {
                if currentPage < onboardingPages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    appState.completeOnboarding()
                }
            }) {
                Text(currentPage < onboardingPages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @State private var isShowingSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo and title
                VStack(spacing: 16) {
                    Image(systemName: "basketball.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("DunkSense AI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your AI-powered jump coach")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Authentication buttons
                VStack(spacing: 16) {
                    Button(action: {
                        signInWithApple()
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        isShowingSignUp.toggle()
                    }) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // Demo login for development
                        demoLogin()
                    }) {
                        Text("Demo Login")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isShowingSignUp) {
            SignUpView()
        }
    }
    
    private func signInWithApple() {
        // Implement Apple Sign In
        Task {
            do {
                let user = try await AuthManager.shared.signInWithApple()
                await MainActor.run {
                    appState.login(user: user)
                }
            } catch {
                print("Apple Sign In failed: \(error)")
            }
        }
    }
    
    private func demoLogin() {
        // Demo user for development
        let demoUser = User(
            id: "demo-user-id",
            name: "Demo User",
            email: "demo@dunksense.ai",
            avatarURL: nil,
            createdAt: Date(),
            age: 25,
            height: 180,
            weight: 75.0,
            sportLevel: .intermediate,
            goals: ["Increase vertical jump", "Improve technique"]
        )
        
        appState.login(user: demoUser)
    }
}

// MARK: - Sign Up View
struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                Button(action: {
                    signUp()
                }) {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .disabled(name.isEmpty || email.isEmpty || password.isEmpty || password != confirmPassword)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func signUp() {
        // Implement sign up logic
        Task {
            do {
                let user = try await AuthManager.shared.signUp(
                    name: name,
                    email: email,
                    password: password
                )
                await MainActor.run {
                    dismiss()
                    // Handle successful sign up
                }
            } catch {
                print("Sign up failed: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
} 