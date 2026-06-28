// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SocksApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SocksCore", targets: ["SocksCore"])
    ],
    targets: [
        .target(
            name: "SocksCore",
            path: "SocksApp/Sources/SocksCore"
        ),
        .testTarget(
            name: "SocksCoreTests",
            dependencies: ["SocksCore"],
            path: "SocksAppTests/SocksCoreTests"
        )
    ]
)
