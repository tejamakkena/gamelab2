// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GameLab",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "GameLabShared", targets: ["GameLabShared"]),
    ],
    dependencies: [
        // Socket.IO Swift client — add via Xcode or SPM
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.0.0"),
    ],
    targets: [
        .target(
            name: "GameLabShared",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "Shared"
        ),
        // Note: GameLabTV and GameLabController are Xcode app targets (not SPM targets).
        // Add them in Xcode and link GameLabShared as a dependency.
    ]
)
