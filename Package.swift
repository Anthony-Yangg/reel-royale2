// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ReelRoyale",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ReelRoyale",
            targets: ["ReelRoyale"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "ReelRoyale",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "ReelRoyale"
        ),
    ]
)

