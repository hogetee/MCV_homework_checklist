// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "InstallerLayout",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/DSStore.git", revision: "6dc395837c3dc371f9c3e71794fab719db74c17a")
    ],
    targets: [
        .executableTarget(name: "InstallerLayout", dependencies: [.product(name: "DSStore", package: "DSStore")])
    ]
)
