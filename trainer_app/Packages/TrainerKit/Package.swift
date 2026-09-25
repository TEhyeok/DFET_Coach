// swift-tools-version: 5.10
// TrainerKit: iOS-only targets (SwiftUI, SwiftData, Vision, Firebase). Verified only through
// iPad simulator `xcodebuild test` (ADR-001, V1-04 §6.2-§6.3, AC-DF-008.3).
//
// Dependency rule (AC-DF-008.2, NFR-03, V1-04 §7.1): the ONLY target that may depend on a Firebase
// product is `FirebaseData`. Feature* targets get `featureDeps` and nothing Firebase, so
// `import FirebaseFirestore` inside a Feature* target fails to compile.
import PackageDescription

let core: [Target.Dependency] = [
  .product(name: "TrainerContracts", package: "TrainerCore"),
  .product(name: "TrainerDomain", package: "TrainerCore"),
]
let featureDeps: [Target.Dependency] = core + [
  "DesignSystem", .product(name: "TrainerAnalytics", package: "TrainerCore"),
]
let featureNames = [
  "FeatureAuth", "FeatureToday", "FeatureMembers", "FeatureSOAP", "FeatureConsent",
  "FeatureBodyComposition", "FeatureAssessment", "FeatureInsights", "FeatureShare",
  "FeatureLidarBeta", "FeatureSettings",
]
let libraryNames = ["LocalStore", "FirebaseData", "PostureVision", "DesignSystem"] + featureNames

let package = Package(
  name: "TrainerKit",
  platforms: [.iOS(.v17)],
  products: libraryNames.map { .library(name: $0, targets: [$0]) },
  dependencies: [
    .package(path: "../TrainerCore"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "11.0.0"),  // ASM-04-11, ASM-S01-06
    // swift-snapshot-testing (test only) is added by the first story that records snapshots (DF-016).
  ],
  targets: [
    .target(name: "LocalStore", dependencies: core + [.product(name: "SyncEngine", package: "TrainerCore")]),
    .target(name: "FirebaseData", dependencies: core + [
      .product(name: "SyncEngine", package: "TrainerCore"),
      .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
      .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
      .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
      .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
      .product(name: "FirebaseAppCheck", package: "firebase-ios-sdk"),
      // FirebaseAnalytics is not linked before G-09 (ADR-015, ASM-04-11).
    ]),
    .target(name: "PostureVision", dependencies: core + [.product(name: "PostureMath", package: "TrainerCore")]),
    .target(name: "DesignSystem", dependencies: core),
    .target(name: "FeatureAuth", dependencies: featureDeps),
    .target(name: "FeatureToday", dependencies: featureDeps),
    .target(name: "FeatureMembers", dependencies: featureDeps),
    .target(name: "FeatureSOAP", dependencies: featureDeps),
    .target(name: "FeatureConsent", dependencies: featureDeps),
    .target(name: "FeatureBodyComposition", dependencies: featureDeps),
    .target(name: "FeatureAssessment", dependencies: featureDeps + [
      "PostureVision", .product(name: "PostureMath", package: "TrainerCore"),
    ]),
    .target(name: "FeatureInsights", dependencies: featureDeps + [.product(name: "PostureMath", package: "TrainerCore")]),
    .target(name: "FeatureShare", dependencies: featureDeps),
    .target(name: "FeatureLidarBeta", dependencies: featureDeps),  // P2 adds BodyPathResult, BodyPathCoreUI (ADR-012)
    .target(name: "FeatureSettings", dependencies: featureDeps),
    .testTarget(name: "LocalStoreTests", dependencies: ["LocalStore"]),
    .testTarget(name: "FirebaseDataTests", dependencies: ["FirebaseData"]),
    .testTarget(name: "PostureVisionTests", dependencies: ["PostureVision"]),
    .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    .testTarget(name: "FeatureModulesTests", dependencies: featureNames.map { Target.Dependency(stringLiteral: $0) }),
  ],
  swiftLanguageVersions: [.v5]
)
