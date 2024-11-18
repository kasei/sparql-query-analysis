// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPARQLQueryAnalysis",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SPARQLQueryAnalysis",
            targets: ["SPARQLQueryAnalysis"]
        ),
		.executable(
			name: "sparql-analyze",
			targets: ["sparql-analyze"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kasei/swift-sparql-syntax.git", .upToNextMinor(from: "0.2.11")),
		.package(url: "https://github.com/kasei/kineo.git", .upToNextMinor(from: "0.0.108")),
        .package(url: "https://github.com/onevcat/Rainbow", .upToNextMajor(from: "4.0.0"))
    ],
    targets: [
    	.target(
    		name: "SPARQLQueryAnalysis",
            dependencies: [
                .product(name: "Kineo", package: "Kineo"),
                .product(name: "SPARQLSyntax", package: "swift-sparql-syntax"),
                "Rainbow"
            ]
    	),
        .executableTarget(
            name: "sparql-analyze",
            dependencies: [
                "SPARQLQueryAnalysis",
                .product(name: "SPARQLSyntax", package: "swift-sparql-syntax"),
            ]
        ),
        .executableTarget(
            name: "sparql-paths",
            dependencies: [
                "SPARQLQueryAnalysis",
                .product(name: "SPARQLSyntax", package: "swift-sparql-syntax"),
            ]
        ),
        .executableTarget(
            name: "sparql-complex-paths",
            dependencies: [
                "SPARQLQueryAnalysis",
                .product(name: "SPARQLSyntax", package: "swift-sparql-syntax"),
            ]
        ),
        .executableTarget(
            name: "sparql-characteristic-sets-multipreds",
            dependencies: [
                "SPARQLQueryAnalysis",
                .product(name: "SPARQLSyntax", package: "swift-sparql-syntax"),
            ]
        ),
        .executableTarget(
            name: "sparql-characteristic-sets",
            dependencies: [
                "SPARQLQueryAnalysis",
                .product(name: "SPARQLSyntax", package: "swift-sparql-syntax"),
            ]
        ),
        .executableTarget(
            name: "sparql-unbound-predicates",
            dependencies: [
                "SPARQLQueryAnalysis",
                .product(name: "SPARQLSyntax", package: "swift-sparql-syntax"),
            ]
        ),
        .executableTarget(
            name: "sparql-subquery-sorts",
            dependencies: [
                "SPARQLQueryAnalysis",
                .product(name: "SPARQLSyntax", package: "swift-sparql-syntax"),
            ]
        ),
        .testTarget(
            name: "SPARQLAnalyzeTests",
            dependencies: [
                "SPARQLQueryAnalysis"
            ]
        ),
    ]
)
