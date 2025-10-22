// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "InsightKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "InsightKit",
            targets: ["InsightKit"]
        ),
    ],
    dependencies: [
        // Testing DSL for async testing
        .package(url: "https://github.com/swift-server/swift-server-testing.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "InsightKit",
            path: "Sources/InsightKit"
        ),
        .testTarget(
            name: "InsightKitTests",
            dependencies: [
                "InsightKit",
                .product(name: "Testing", package: "swift-server-testing"),
            ],
            path: "Tests/InsightKitTests"
        ),
    ]
)
