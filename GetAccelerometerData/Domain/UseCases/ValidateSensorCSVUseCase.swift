import Foundation

// MARK: - ValidateSensorCSVUseCaseProtocol
// CSV 形式の業務ルール（必須カラム / 数値妥当性 / 行数）を検証する Domain UseCase。
// 旧 `DataExportService.validateCSVFormat`（Utility 配置）から移管（ISSUE-014）。
protocol ValidateSensorCSVUseCaseProtocol: Sendable {
    /// CSV 文字列を検証し、本アプリで読み込み可能な形式であれば `true` を返す。
    /// 検出した問題は `print` でログ出力する（呼び出し側で詳細制御したい場合は将来 Result 化）。
    func execute(csvString: String) -> Bool
}

// MARK: - ValidateSensorCSVUseCase
final class ValidateSensorCSVUseCase: ValidateSensorCSVUseCaseProtocol {

    /// 現行 9 列フォーマット（加速度 + ジャイロ統合）
    private static let currentColumns: [String] = [
        "timestamp",
        "accel_x", "accel_y", "accel_z", "accel_magnitude",
        "gyro_x", "gyro_y", "gyro_z", "gyro_magnitude"
    ]

    /// 旧 5 列フォーマット（加速度のみ・後方互換）
    private static let legacyColumns: [String] = [
        "timestamp", "x", "y", "z", "magnitude"
    ]

    func execute(csvString: String) -> Bool {
        // 空の CSV は無効
        if csvString.isEmpty {
            print("CSVファイルが空です")
            return false
        }

        let rows = csvString.components(separatedBy: "\n")
        guard !rows.isEmpty else {
            print("CSVファイルに行がありません")
            return false
        }

        // ヘッダー解析
        let header = rows[0].components(separatedBy: ",")
        guard !header.isEmpty else {
            print("CSVヘッダーが無効です")
            return false
        }
        let headerLowercased = header.map {
            $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 現行 9 列・旧 5 列のいずれかに完全一致すれば OK
        let matchesCurrent = Self.currentColumns.allSatisfy { col in
            headerLowercased.contains(col)
        }
        let matchesLegacy = Self.legacyColumns.allSatisfy { col in
            headerLowercased.contains(col)
        }
        guard matchesCurrent || matchesLegacy else {
            let missingCurrent = Self.currentColumns.filter { !headerLowercased.contains($0) }
            print("CSVファイルに必要なカラムがありません（現行 9 列 / 旧 5 列いずれにも該当せず）: \(missingCurrent.joined(separator: ", "))")
            return false
        }

        // データ行が 1 行以上必要
        guard rows.count >= 2 else {
            print("CSVファイルにデータ行がありません")
            return false
        }

        // 各行のカラム数チェック
        let expectedColumnCount = header.count
        var invalidRowIndices: [Int] = []
        for (index, row) in rows.dropFirst().enumerated() {
            if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            let columns = row.components(separatedBy: ",")
            if columns.count != expectedColumnCount {
                invalidRowIndices.append(index + 1)
                if invalidRowIndices.count >= 5 { break }
            }
        }
        if !invalidRowIndices.isEmpty {
            let strings = invalidRowIndices.map { String($0) }
            print("以下の行のカラム数がヘッダーと一致しません: \(strings.joined(separator: ", "))")
            return false
        }

        // 数値カラム妥当性チェック（マッチした方のフォーマットに基づく）
        let numericColumnNames: [String] = matchesCurrent
            ? ["accel_x", "accel_y", "accel_z", "accel_magnitude",
               "gyro_x", "gyro_y", "gyro_z", "gyro_magnitude"]
            : ["x", "y", "z", "magnitude"]

        let numericIndices: [Int] = numericColumnNames.compactMap { name in
            headerLowercased.firstIndex(of: name)
        }

        var invalidNumberRows: [Int] = []
        for (index, row) in rows.dropFirst().enumerated() {
            if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            let columns = row.components(separatedBy: ",")
            if columns.count < expectedColumnCount { continue }

            let invalidNumbers = numericIndices.filter { i in
                let value = columns[i].trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = value.lowercased()
                if lower == "nan" || lower == "infinity" || lower == "-infinity" {
                    return true
                }
                return Double(value) == nil
            }
            if !invalidNumbers.isEmpty {
                invalidNumberRows.append(index + 1)
                if invalidNumberRows.count >= 5 { break }
            }
        }
        if !invalidNumberRows.isEmpty {
            let strings = invalidNumberRows.map { String($0) }
            print("以下の行に無効な数値があります: \(strings.joined(separator: ", "))")
            return false
        }

        return true
    }
}
