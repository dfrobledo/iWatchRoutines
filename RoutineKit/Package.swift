// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RoutineKit",
    platforms: [.watchOS(.v10), .iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RoutineKit", targets: ["RoutineKit"]),
    ],
    targets: [
        .target(name: "RoutineKit"),
        .testTarget(name: "RoutineKitTests", dependencies: ["RoutineKit"]),
    ]
)
