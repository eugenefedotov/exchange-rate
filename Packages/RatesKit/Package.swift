// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RatesKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RatesKit", targets: ["RatesKit"]),
        .executable(name: "rates", targets: ["rates"]),
    ],
    targets: [
        .target(name: "RatesKit"),
        .executableTarget(name: "rates", dependencies: ["RatesKit"]),
        .testTarget(
            name: "RatesKitTests",
            dependencies: ["RatesKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
