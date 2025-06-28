// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DunkSenseApp",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "DunkSenseApp",
            targets: ["DunkSenseApp"]
        ),
    ],
    dependencies: [
        // Core ML and Vision
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        
        // Networking
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        .package(url: "https://github.com/grpc/grpc-swift", from: "1.21.0"),
        
        // Database
        .package(url: "https://github.com/realm/realm-swift", from: "10.45.0"),
        
        // UI Components
        .package(url: "https://github.com/airbnb/lottie-ios", from: "4.4.0"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", from: "1.1.0"),
        
        // Charts and Visualization
        .package(url: "https://github.com/danielgindi/Charts", from: "5.0.0"),
        
        // Utilities
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", from: "5.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
        
        // Testing
        .package(url: "https://github.com/Quick/Quick", from: "7.4.0"),
        .package(url: "https://github.com/Quick/Nimble", from: "13.2.0"),
    ],
    targets: [
        .target(
            name: "DunkSenseApp",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
                .product(name: "DGCharts", package: "Charts"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),
        .testTarget(
            name: "DunkSenseAppTests",
            dependencies: [
                "DunkSenseApp",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ]
        ),
    ]
) 