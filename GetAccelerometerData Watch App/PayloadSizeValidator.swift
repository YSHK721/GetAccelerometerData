//
//  PayloadSizeValidator.swift
//  GetAccelerometerData Watch App
//
//  Created by i on 2025/05/29.
//

import Foundation
import WatchConnectivity

/// ペイロードサイズの検証と転送方法の推奨を行うクラス
class PayloadSizeValidator {
    
    // MARK: - Constants
    
    /// WatchConnectivity sendMessageDataメソッドの実測制限（64KB）
    private static let immediateTransferLimit = 65_536 // 64KB
    
    /// transferUserInfoメソッドの実測制限（128KB）
    private static let backgroundTransferLimit = 131_072 // 128KB
    
    /// 転送方法の推奨閾値（安全マージンを考慮して60KBで切り替え）
    private static let recommendedThreshold = 61_440 // 60KB
    
    /// 最大転送可能サイズ（120KBで安全マージン）
    private static let maximumTransferLimit = 122_880 // 120KB
    
    // MARK: - Transfer Method Enum
    
    /// データ転送方法
    enum TransferMethod {
        case immediate     // sendMessageData使用（64KB制限内）
        case background    // transferUserInfo使用（128KB制限内）
        case file          // transferFile使用（サイズ制限なし、バックグラウンド転送）

        var description: String {
            switch self {
            case .immediate:
                return "即時転送（sendMessageData）"
            case .background:
                return "バックグラウンド転送（transferUserInfo）"
            case .file:
                return "ファイル転送（transferFile）"
            }
        }
    }
    
    // MARK: - Error Types
    
    /// ペイロードサイズ関連のエラー
    enum PayloadSizeError: Error, LocalizedError {
        case exceedsImmediateTransferLimit(actualSize: Int, limit: Int)
        case exceedsBackgroundTransferLimit(actualSize: Int, limit: Int)
        case exceedsMaximumTransferLimit(actualSize: Int, limit: Int)
        case encodingFailed(underlyingError: Error)
        
        var errorDescription: String? {
            switch self {
            case .exceedsImmediateTransferLimit(let actualSize, let limit):
                return "ペイロードサイズ (\(actualSize) bytes) が即時転送制限 (\(limit) bytes) を超えています"
            case .exceedsBackgroundTransferLimit(let actualSize, let limit):
                return "ペイロードサイズ (\(actualSize) bytes) がバックグラウンド転送制限 (\(limit) bytes) を超えています"
            case .exceedsMaximumTransferLimit(let actualSize, let limit):
                return "ペイロードサイズ (\(actualSize) bytes) が最大転送制限 (\(limit) bytes) を超えています"
            case .encodingFailed(let underlyingError):
                return "データエンコーディングに失敗: \(underlyingError.localizedDescription)"
            }
        }
    }
    
    // MARK: - Validation Methods
    
    /// データが即時転送制限内かどうかを判定
    /// - Parameter data: 検証対象のデータ
    /// - Returns: 64KB制限内の場合true
    func isWithinImmediateTransferLimit(_ data: Data) -> Bool {
        return data.count <= Self.immediateTransferLimit
    }
    
    /// データがバックグラウンド転送制限内かどうかを判定
    /// - Parameter data: 検証対象のデータ
    /// - Returns: 128KB制限内の場合true
    func isWithinBackgroundTransferLimit(_ data: Data) -> Bool {
        return data.count <= Self.backgroundTransferLimit
    }
    
    /// データが最大転送制限内かどうかを判定
    /// - Parameter data: 検証対象のデータ
    /// - Returns: 120KB制限内の場合true
    func isWithinMaximumTransferLimit(_ data: Data) -> Bool {
        return data.count <= Self.maximumTransferLimit
    }
    
    /// データサイズに基づいて最適な転送方法を推奨
    /// - Parameter data: 転送対象のデータ
    /// - Returns: 推奨される転送方法
    func recommendedTransferMethod(for data: Data) -> TransferMethod {
        if data.count <= Self.recommendedThreshold {
            return .immediate
        } else if data.count <= Self.backgroundTransferLimit {
            return .background
        } else {
            return .file
        }
    }
    
    /// JSONエンコード可能なオブジェクトのサイズを計算して転送方法を推奨
    /// - Parameter encodableObject: エンコード対象のオブジェクト
    /// - Returns: 推奨される転送方法
    /// - Throws: エンコーディングに失敗した場合
    func recommendedTransferMethod<T: Codable>(for encodableObject: T) throws -> TransferMethod {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(encodableObject)
            return recommendedTransferMethod(for: data)
        } catch {
            throw PayloadSizeError.encodingFailed(underlyingError: error)
        }
    }
    
    /// 即時転送のバリデーション（64KB制限チェック）
    /// - Parameter data: 検証対象のデータ
    /// - Throws: 制限を超えている場合
    func validateImmediateTransfer(_ data: Data) throws {
        if !isWithinImmediateTransferLimit(data) {
            throw PayloadSizeError.exceedsImmediateTransferLimit(
                actualSize: data.count,
                limit: Self.immediateTransferLimit
            )
        }
    }
    
    /// バックグラウンド転送のバリデーション（128KB制限チェック）
    /// - Parameter data: 検証対象のデータ
    /// - Throws: 制限を超えている場合
    func validateBackgroundTransfer(_ data: Data) throws {
        if !isWithinBackgroundTransferLimit(data) {
            throw PayloadSizeError.exceedsBackgroundTransferLimit(
                actualSize: data.count,
                limit: Self.backgroundTransferLimit
            )
        }
    }
    
    /// 転送データの総合バリデーション（最大制限チェック）
    /// - Parameter data: 検証対象のデータ
    /// - Throws: 制限を超えている場合
    func validateTransfer(_ data: Data) throws {
        if !isWithinMaximumTransferLimit(data) {
            throw PayloadSizeError.exceedsMaximumTransferLimit(
                actualSize: data.count,
                limit: Self.maximumTransferLimit
            )
        }
    }
    
    // MARK: - Size Information Methods
    
    /// データサイズの詳細情報を取得
    /// - Parameter data: 対象データ
    /// - Returns: サイズ情報の辞書
    func getSizeInfo(for data: Data) -> [String: Any] {
        let sizeInBytes = data.count
        let sizeInKB = Double(sizeInBytes) / 1024.0
        let immediateUtilizationRate = Double(sizeInBytes) / Double(Self.immediateTransferLimit) * 100.0
        let backgroundUtilizationRate = Double(sizeInBytes) / Double(Self.backgroundTransferLimit) * 100.0
        
        return [
            "sizeInBytes": sizeInBytes,
            "sizeInKB": String(format: "%.2f", sizeInKB),
            "immediateTransferLimit": Self.immediateTransferLimit,
            "backgroundTransferLimit": Self.backgroundTransferLimit,
            "maximumTransferLimit": Self.maximumTransferLimit,
            "immediateUtilizationRate": String(format: "%.1f", immediateUtilizationRate) + "%",
            "backgroundUtilizationRate": String(format: "%.1f", backgroundUtilizationRate) + "%",
            "canUseImmediateTransfer": isWithinImmediateTransferLimit(data),
            "canUseBackgroundTransfer": isWithinBackgroundTransferLimit(data),
            "canTransfer": isWithinMaximumTransferLimit(data),
            "recommendedMethod": recommendedTransferMethod(for: data).description
        ]
    }
    
    /// データサイズの詳細情報を文字列形式で取得
    /// - Parameter data: 対象データ
    /// - Returns: サイズ情報の文字列
    func getSizeInfoString(for data: Data) -> String {
        let sizeInBytes = data.count
        let sizeInKB = Double(sizeInBytes) / 1024.0
        let immediateUtilizationRate = Double(sizeInBytes) / Double(Self.immediateTransferLimit) * 100.0
        let backgroundUtilizationRate = Double(sizeInBytes) / Double(Self.backgroundTransferLimit) * 100.0
        
        var info = "データサイズ: \(String(format: "%.1f", sizeInKB)) KB (\(sizeInBytes) bytes)\n"
        info += "即時転送利用率: \(String(format: "%.1f", immediateUtilizationRate))%\n"
        info += "バックグラウンド転送利用率: \(String(format: "%.1f", backgroundUtilizationRate))%\n"
        info += "推奨転送方法: \(recommendedTransferMethod(for: data).description)"
        
        return info
    }
    
    /// 複数のデータオブジェクトの総サイズを計算
    /// - Parameter dataArray: データ配列
    /// - Returns: 総サイズ（バイト）
    func calculateTotalSize(_ dataArray: [Data]) -> Int {
        return dataArray.reduce(0) { $0 + $1.count }
    }
    
    // MARK: - Static Convenience Methods
    
    /// 静的メソッド: データサイズの簡易チェック
    /// - Parameter data: 検証対象のデータ
    /// - Returns: 64KB制限内の場合true
    static func canUseImmediateTransfer(for data: Data) -> Bool {
        return data.count <= immediateTransferLimit
    }
    
    /// 静的メソッド: 転送方法の簡易推奨
    /// - Parameter dataSize: データサイズ（バイト）
    /// - Returns: 推奨される転送方法
    static func recommendTransferMethod(for dataSize: Int) -> TransferMethod {
        if dataSize <= recommendedThreshold {
            return .immediate
        } else if dataSize <= backgroundTransferLimit {
            return .background
        } else {
            return .file
        }
    }
}

// MARK: - PayloadSizeValidator Extension for Logging

extension PayloadSizeValidator {
    
    /// デバッグ用：データサイズ情報をコンソールに出力
    /// - Parameters:
    ///   - data: 対象データ
    ///   - label: ラベル（オプション）
    func logSizeInfo(for data: Data, label: String = "Data") {
        let info = getSizeInfo(for: data)
        
        print("=== \(label) サイズ情報 ===")
        print("サイズ: \(info["sizeInBytes"] ?? 0) bytes (\(info["sizeInKB"] ?? "0.00") KB)")
        print("即時転送制限利用率: \(info["immediateUtilizationRate"] ?? "0.0%")")
        print("バックグラウンド転送制限利用率: \(info["backgroundUtilizationRate"] ?? "0.0%")")
        print("即時転送可能: \(info["canUseImmediateTransfer"] as? Bool == true ? "Yes" : "No")")
        print("バックグラウンド転送可能: \(info["canUseBackgroundTransfer"] as? Bool == true ? "Yes" : "No")")
        print("転送可能: \(info["canTransfer"] as? Bool == true ? "Yes" : "No")")
        print("推奨転送方法: \(info["recommendedMethod"] ?? "Unknown")")
        print("========================")
    }
}
