// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Decoy",
  platforms: [.iOS(.v15)],
  products: [
    .library(
      name: "Decoy",
      targets: ["Decoy"]
    ),
    .library(
      name: "DecoyApollo",
      targets: ["DecoyApollo"]
    ),
    .library(
      name: "DecoyXCUI",
      targets: ["DecoyXCUI"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apollographql/apollo-ios", from: "1.18.0"),
  ],
  targets: [
    .target(
      name: "Decoy"
    ),
    .target(
      name: "DecoyApollo",
      dependencies: [
        "Decoy",
        .product(name: "Apollo", package: "apollo-ios")
      ]
    ),
    .target(
      name: "DecoyXCUI",
      dependencies: ["Decoy"]
    ),
    .testTarget(
      name: "DecoyTests",
      dependencies: ["Decoy"],
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "DecoyIntegrationTests",
      dependencies: ["Decoy"]
    ),
    .testTarget(
      name: "DecoyApolloTests",
      dependencies: ["DecoyApollo"]
    ),
  ]
)
