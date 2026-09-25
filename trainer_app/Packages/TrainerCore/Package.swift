// swift-tools-version: 5.10
// TrainerCore: pure Swift targets that compile on iOS 17 and macOS 14 so that
// `swift test --package-path trainer_app/Packages/TrainerCore` runs without a simulator.
// Never import UIKit, SwiftUI, SwiftData or Firebase here (ADR-001, V1-04 §6.2, AC-DF-008.3).
import PackageDescription

let strict: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
  name: "TrainerCore",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "TrainerContracts", targets: ["TrainerContracts"]),
    .library(name: "TrainerDomain", targets: ["TrainerDomain"]),
    .library(name: "PostureMath", targets: ["PostureMath"]),
    .library(name: "SyncEngine", targets: ["SyncEngine"]),
    .library(name: "TrainerAnalytics", targets: ["TrainerAnalytics"]),
  ],
  targets: [
    .target(name: "TrainerContracts", swiftSettings: strict),
    .target(name: "TrainerDomain", dependencies: ["TrainerContracts"], swiftSettings: strict),
    .target(name: "PostureMath", dependencies: ["TrainerContracts", "TrainerDomain"], swiftSettings: strict),
    .target(name: "SyncEngine", dependencies: ["TrainerDomain"], swiftSettings: strict),  // no LocalStore (ASM-04-02)
    .target(name: "TrainerAnalytics", dependencies: ["TrainerContracts"], swiftSettings: strict),
    .testTarget(name: "TrainerContractsTests", dependencies: ["TrainerContracts"]),
    .testTarget(name: "TrainerDomainTests", dependencies: ["TrainerDomain"]),
    .testTarget(name: "PostureMathTests", dependencies: ["PostureMath"]),
    .testTarget(name: "SyncEngineTests", dependencies: ["SyncEngine"]),
    .testTarget(name: "TrainerAnalyticsTests", dependencies: ["TrainerAnalytics"]),
  ],
  swiftLanguageVersions: [.v5]
)
