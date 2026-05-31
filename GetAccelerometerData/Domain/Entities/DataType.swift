// MARK: - DataType
// データ表示の種類（Domain Entity）
enum DataType: String, CaseIterable, Equatable, Sendable {
    case all = "すべて"
    case xAxis = "X軸"
    case yAxis = "Y軸"
    case zAxis = "Z軸"
    case magnitude = "合成加速度"
}
