import Foundation
import Alamofire
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let baseURL = "http://localhost:8080/api/v1"
    private let session: Session
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isConnected = true
    @Published var authToken: String?
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        self.session = Session(configuration: configuration)
        
        loadAuthToken()
        setupNetworkMonitoring()
    }
    
    // MARK: - Authentication
    private func loadAuthToken() {
        self.authToken = UserDefaults.standard.string(forKey: "auth_token")
    }
    
    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    func clearAuthToken() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        // Monitor network reachability
        NetworkReachabilityManager()?.startListening { [weak self] status in
            DispatchQueue.main.async {
                self?.isConnected = status != .notReachable
            }
        }
    }
    
    // MARK: - Request Headers
    private var defaultHeaders: HTTPHeaders {
        var headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        if let token = authToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
    
    // MARK: - Authentication API
    func signIn(email: String, password: String) async throws -> AuthResponse {
        let parameters = [
            "email": email,
            "password": password
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/auth/signin",
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default
            )
            .validate()
            .responseDecodable(of: AuthResponse.self) { response in
                switch response.result {
                case .success(let authResponse):
                    self.setAuthToken(authResponse.token)
                    continuation.resume(returning: authResponse)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func signUp(user: SignUpRequest) async throws -> AuthResponse {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/auth/signup",
                method: .post,
                parameters: user,
                encoder: JSONParameterEncoder.default
            )
            .validate()
            .responseDecodable(of: AuthResponse.self) { response in
                switch response.result {
                case .success(let authResponse):
                    self.setAuthToken(authResponse.token)
                    continuation.resume(returning: authResponse)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func signOut() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/auth/signout",
                method: .post,
                headers: defaultHeaders
            )
            .validate()
            .response { response in
                self.clearAuthToken()
                
                switch response.result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Metrics API
    func fetchRecentMetrics(limit: Int = 10) async throws -> [JumpMetric] {
        let parameters = ["limit": limit]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/metrics/recent",
                method: .get,
                parameters: parameters,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: [JumpMetric].self) { response in
                switch response.result {
                case .success(let metrics):
                    continuation.resume(returning: metrics)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchMetrics(from startDate: Date, to endDate: Date) async throws -> [JumpMetric] {
        let dateFormatter = ISO8601DateFormatter()
        let parameters = [
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate)
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/metrics",
                method: .get,
                parameters: parameters,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: [JumpMetric].self) { response in
                switch response.result {
                case .success(let metrics):
                    continuation.resume(returning: metrics)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchPersonalBest() async throws -> JumpMetric {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/metrics/personal-best",
                method: .get,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: JumpMetric.self) { response in
                switch response.result {
                case .success(let metric):
                    continuation.resume(returning: metric)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchWeeklyStats() async throws -> WeeklyStats {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/metrics/weekly-stats",
                method: .get,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: WeeklyStats.self) { response in
                switch response.result {
                case .success(let stats):
                    continuation.resume(returning: stats)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchAllMetrics() async throws -> [JumpMetric] {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/metrics/all",
                method: .get,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: [JumpMetric].self) { response in
                switch response.result {
                case .success(let metrics):
                    continuation.resume(returning: metrics)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func saveJumpMetric(_ metric: JumpMetric) async throws -> JumpMetric {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/metrics",
                method: .post,
                parameters: metric,
                encoder: JSONParameterEncoder.default,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: JumpMetric.self) { response in
                switch response.result {
                case .success(let savedMetric):
                    continuation.resume(returning: savedMetric)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func saveTrainingSession(_ session: TrainingSession) async throws -> TrainingSession {
        return try await withCheckedThrowingContinuation { continuation in
            self.session.request(
                "\(baseURL)/sessions",
                method: .post,
                parameters: session,
                encoder: JSONParameterEncoder.default,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: TrainingSession.self) { response in
                switch response.result {
                case .success(let savedSession):
                    continuation.resume(returning: savedSession)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Video Analysis API
    func analyzeVideo(url: URL) async throws -> JumpAnalysisResult {
        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { multipartFormData in
                    multipartFormData.append(url, withName: "video", fileName: "jump.mov", mimeType: "video/quicktime")
                },
                to: "\(baseURL)/analysis/video",
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: JumpAnalysisResult.self) { response in
                switch response.result {
                case .success(let result):
                    continuation.resume(returning: result)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func uploadVideo(_ url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { multipartFormData in
                    multipartFormData.append(url, withName: "video", fileName: "jump.mov", mimeType: "video/quicktime")
                },
                to: "\(baseURL)/upload/video",
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: UploadResponse.self) { response in
                switch response.result {
                case .success(let uploadResponse):
                    continuation.resume(returning: uploadResponse.url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - User Profile API
    func fetchUserProfile() async throws -> User {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/user/profile",
                method: .get,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: User.self) { response in
                switch response.result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateUserProfile(_ user: User) async throws -> User {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/user/profile",
                method: .put,
                parameters: user,
                encoder: JSONParameterEncoder.default,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: User.self) { response in
                switch response.result {
                case .success(let updatedUser):
                    continuation.resume(returning: updatedUser)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Community API
    func fetchLeaderboard(period: String = "week") async throws -> [LeaderboardEntry] {
        let parameters = ["period": period]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/community/leaderboard",
                method: .get,
                parameters: parameters,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: [LeaderboardEntry].self) { response in
                switch response.result {
                case .success(let entries):
                    continuation.resume(returning: entries)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchChallenges() async throws -> [Challenge] {
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(baseURL)/community/challenges",
                method: .get,
                headers: defaultHeaders
            )
            .validate()
            .responseDecodable(of: [Challenge].self) { response in
                switch response.result {
                case .success(let challenges):
                    continuation.resume(returning: challenges)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: AFError) -> NetworkError {
        switch error {
        case .sessionTaskFailed(let sessionError):
            if let urlError = sessionError as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return .noInternetConnection
                case .timedOut:
                    return .timeout
                default:
                    return .networkError(urlError.localizedDescription)
                }
            }
            return .networkError(sessionError.localizedDescription)
            
        case .responseValidationFailed(let reason):
            switch reason {
            case .unacceptableStatusCode(let code):
                switch code {
                case 401:
                    return .unauthorized
                case 403:
                    return .forbidden
                case 404:
                    return .notFound
                case 500...599:
                    return .serverError
                default:
                    return .httpError(code)
                }
            default:
                return .validationError(reason.localizedDescription)
            }
            
        case .responseSerializationFailed(let reason):
            return .decodingError(reason.localizedDescription)
            
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - Response Models
struct AuthResponse: Codable {
    let token: String
    let user: User
    let expiresAt: Date
}

struct SignUpRequest: Codable {
    let name: String
    let email: String
    let password: String
    let age: Int?
    let height: Double?
    let weight: Double?
    let sportLevel: String?
}

struct UploadResponse: Codable {
    let url: String
    let fileName: String
}

struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let rank: Int
    let userName: String
    let avatarURL: String?
    let bestJumpHeight: Double
    let totalJumps: Int
    let points: Int
}

struct Challenge: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let startDate: Date
    let endDate: Date
    let targetValue: Double
    let unit: String
    let reward: String
    let participants: Int
    let isParticipating: Bool
    let progress: Double
}

// MARK: - Network Error
enum NetworkError: LocalizedError {
    case noInternetConnection
    case timeout
    case unauthorized
    case forbidden
    case notFound
    case serverError
    case httpError(Int)
    case networkError(String)
    case validationError(String)
    case decodingError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noInternetConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error occurred"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .decodingError(let message):
            return "Data decoding error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
} 