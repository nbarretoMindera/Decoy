// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Decoy",
  products: [
    .library(
      name: "Decoy",
      targets: ["Decoy"]
    ),
    .library(
      name: "DecoyXCUI",
      targets: ["DecoyXCUI"]
    ),
  ],
  targets: [
    .target(
      name: "Decoy"
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
  ]
)
