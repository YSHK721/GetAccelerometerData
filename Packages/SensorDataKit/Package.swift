// swift-tools-version: 6.0
import PackageDescription

// MARK: - SensorDataKit
// iOS と watchOS の両ターゲットで共有する Domain モデル / フォーマッタを提供する Local Swift Package。
// ISSUE-015 対応：iOS / Watch 間の重複定義（CSVTimestampFormatter / SensorRecords / CombinedSensorData）を解消。
let package = Package(
    name: "SensorDataKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "SensorDataKit",
            targets: ["SensorDataKit"]
        )
    ],
    targets: [
        .target(
            name: "SensorDataKit",
            path: "Sources/SensorDataKit"
        )
    ]
)
