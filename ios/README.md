# DunkSense iOS App

DunkSense is an AI-powered iOS application for analyzing basketball jump performance using computer vision and pose estimation.

## Features

### 🏀 Jump Analysis
- Real-time pose detection using Vision framework
- Jump height measurement and analysis
- Flight time and contact time calculation
- Takeoff velocity and landing force estimation
- Symmetry and technique scoring

### 📊 Performance Tracking
- Personal best tracking
- Progress visualization with charts
- Weekly and monthly statistics
- Training insights and recommendations
- Export data in CSV, JSON, or PDF formats

### 📱 Modern iOS Experience
- SwiftUI-based modern interface
- Camera integration for video recording
- Real-time pose overlay during recording
- Smooth animations and transitions
- Dark mode support

### 👥 Community Features
- Leaderboards with weekly/monthly rankings
- Challenges and competitions
- Friend system and social features
- Achievement system

## Technical Stack

### Frameworks & Libraries
- **SwiftUI** - Modern declarative UI framework
- **Vision** - Apple's computer vision framework for pose estimation
- **CoreML** - Machine learning model integration
- **AVFoundation** - Camera and video processing
- **Charts** - Data visualization
- **Alamofire** - Networking
- **Realm** - Local database
- **Combine** - Reactive programming

### Architecture
- **MVVM Pattern** - Clean separation of concerns
- **ObservableObject** - State management with Combine
- **Dependency Injection** - Modular and testable code
- **Repository Pattern** - Data access abstraction

## Project Structure

```
ios/DunkSenseApp/
├── App/
│   ├── DunkSenseApp.swift      # Main app entry point
│   └── ContentView.swift       # Root view with navigation
├── Views/
│   ├── HomeView.swift          # Dashboard and quick stats
│   ├── JumpCaptureView.swift   # Camera and recording interface
│   ├── ProgressView.swift      # Analytics and progress tracking
│   ├── ProfileView.swift       # User profile and settings
│   └── CommunityView.swift     # Social features and leaderboards
├── Models/
│   └── JumpMetric.swift        # Data models and structures
├── Services/
│   ├── CameraManager.swift     # Camera and video recording
│   ├── PoseEstimationService.swift # AI pose analysis
│   ├── MetricsManager.swift    # Data management
│   ├── NetworkManager.swift    # API communication
│   └── CacheManager.swift      # Local caching
└── Package.swift               # Swift Package Manager dependencies
```

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 15.0 or later
- Swift 5.10 or later

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-repo/dunksense.git
   cd dunksense/ios
   ```

2. **Install dependencies**
   Dependencies are managed through Swift Package Manager and will be automatically resolved when you open the project in Xcode.

3. **Configure backend URL**
   Update the `baseURL` in `NetworkManager.swift`:
   ```swift
   private let baseURL = "https://your-api-domain.com/api/v1"
   ```

4. **Build and run**
   - Open `DunkSenseApp` in Xcode
   - Select your target device or simulator
   - Press `Cmd+R` to build and run

### Configuration

#### Info.plist Permissions
The app requires the following permissions:
```xml
<key>NSCameraUsageDescription</key>
<string>DunkSense needs camera access to record and analyze your jumps.</string>
<key>NSMicrophoneUsageDescription</key>
<string>DunkSense needs microphone access to record jump videos.</string>
<key>NSMotionUsageDescription</key>
<string>DunkSense uses motion data to enhance jump analysis.</string>
```

#### App Transport Security
For development with local backend:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## Key Components

### CameraManager
Handles camera setup, recording, and real-time video processing:
- Camera permission management
- Video recording with quality settings
- Real-time frame processing for pose estimation
- Camera switching (front/back)

### PoseEstimationService
AI-powered pose analysis using Apple's Vision framework:
- Real-time human pose detection
- Jump phase detection (preparation, takeoff, flight, landing)
- Biomechanical analysis (symmetry, technique scoring)
- Performance metrics calculation

### MetricsManager
Centralized data management for jump metrics:
- Local caching with disk persistence
- Network synchronization
- Statistics calculation and insights
- Data export functionality

### NetworkManager
API communication with backend services:
- Authentication and user management
- Metrics upload and synchronization
- Community features (leaderboards, challenges)
- Error handling and retry logic

## Data Models

### JumpMetric
Core data structure for jump analysis:
```swift
struct JumpMetric {
    let jumpHeight: Double          // Height in centimeters
    let contactTime: Double         // Ground contact time
    let flightTime: Double          // Time in air
    let takeoffVelocity: Double     // Initial velocity
    let landingForce: Double        // Impact force
    let symmetryScore: Double       // Left-right balance (0-1)
    let techniqueScore: Double      // Form quality (0-1)
    let poseData: [PoseData]        // Frame-by-frame pose data
}
```

### Performance Metrics
- **Jump Height**: Calculated from hip trajectory analysis
- **Flight Time**: Duration from takeoff to landing
- **Contact Time**: Ground contact during preparation
- **Symmetry Score**: Balance between left and right sides
- **Technique Score**: Overall form quality assessment

## Testing

### Unit Tests
Run unit tests with:
```bash
xcodebuild test -scheme DunkSenseApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

### UI Tests
Automated UI testing for critical user flows:
- Onboarding and authentication
- Jump recording and analysis
- Data visualization and export

## Performance Optimization

### Camera Processing
- Optimized frame processing on background queues
- Efficient pose detection with Vision framework
- Memory management for video buffers

### Data Management
- Intelligent caching strategy
- Background data synchronization
- Optimized Core Data queries

### UI Rendering
- SwiftUI best practices for smooth animations
- Lazy loading for large data sets
- Efficient chart rendering

## Deployment

### App Store Distribution
1. **Archive the app** in Xcode
2. **Upload to App Store Connect**
3. **Configure app metadata** and screenshots
4. **Submit for review**

### TestFlight Beta
1. **Upload beta build** to App Store Connect
2. **Add beta testers** via email
3. **Distribute beta versions** for testing

## Troubleshooting

### Common Issues

**Camera not working**
- Check camera permissions in Settings
- Ensure device has camera capability
- Verify Info.plist permissions

**Pose detection not accurate**
- Ensure good lighting conditions
- Check camera angle and distance
- Verify Vision framework availability

**Network errors**
- Check internet connectivity
- Verify backend API endpoints
- Review authentication tokens

### Debug Tools
- Xcode debugger and console
- Network traffic monitoring
- Performance profiling with Instruments

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical support or questions:
- Create an issue on GitHub
- Contact the development team
- Check the documentation wiki

---

**DunkSense iOS App** - Elevate your game with AI-powered jump analysis! 🏀📱 