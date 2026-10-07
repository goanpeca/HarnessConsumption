// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentConsumption",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ConsumptionKit", targets: ["ConsumptionKit"]),
        .executable(name: "AgentConsumption", targets: ["AgentConsumption"]),
    ],
    targets: [
        .target(name: "ConsumptionKit"),
        .executableTarget(name: "AgentConsumption", dependencies: ["ConsumptionKit"]),
        .testTarget(name: "ConsumptionKitTests", dependencies: ["ConsumptionKit"]),
    ]
)
