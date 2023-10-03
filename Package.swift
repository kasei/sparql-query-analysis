// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPARQLQueryAnalysis",
    products: [
        .library(
            name: "SPARQLQueryAnalysis",
            targets: ["SPARQLQueryAnalysis"]
        ),
    ],
    dependencies: [
		.package(name: "SPARQLSyntax", url: "https://github.com/kasei/swift-sparql-syntax.git", .upToNextMinor(from: "0.0.82")),
		.package(name: "Kineo", url: "https://github.com/kasei/kineo.git", .upToNextMinor(from: "0.0.30"))
    ],
    targets: [
    	.target(
    		name: "SPARQLQueryAnalysis",
            dependencies: ["Kineo", "SPARQLSyntax"]
    	),
        .target(
            name: "sparql-paths",
            dependencies: ["SPARQLQueryAnalysis", "SPARQLSyntax"]
        ),
        .target(
            name: "sparql-characteristic-sets-multipreds",
            dependencies: ["SPARQLQueryAnalysis", "SPARQLSyntax"]
        ),
        .target(
            name: "sparql-characteristic-sets",
            dependencies: ["SPARQLQueryAnalysis", "SPARQLSyntax"]
        ),
        .target(
            name: "sparql-unbound-predicates",
            dependencies: ["SPARQLQueryAnalysis", "SPARQLSyntax"]
        ),
        .target(
            name: "sparql-subquery-sorts",
            dependencies: ["SPARQLQueryAnalysis", "SPARQLSyntax"]
        ),
    ]
)
