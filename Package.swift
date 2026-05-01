// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SkillShortCuts",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SkillShortCuts", targets: ["SkillShortCutsNative"])
    ],
    targets: [
        .executableTarget(
            name: "SkillShortCutsNative",
            path: "Sources/SkillShortCutsNative"
        ),
        .testTarget(
            name: "SkillShortCutsNativeTests",
            dependencies: ["SkillShortCutsNative"],
            path: "Tests/SkillShortCutsNativeTests"
        )
    ]
)
