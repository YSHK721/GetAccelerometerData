import Foundation

// MARK: - VBT Labeling Ports
// VBT Ground Truth Tool Phase C: 仕様書 §10 ラベリング UI 用 Output Boundary 群。
// Clean Architecture / DIP: UseCase 層が依存する抽象。Infrastructure 実装は iOS app 側に隔離。
//
// ISP: クライアントごとに最小機能。
//   - SessionListLoaderPort:    Documents 配下の session_* 列挙 + meta.json 読み込み
//   - IMUWaveformLoaderPort:    imu.csv 読み込み（accel_magnitude 抽出）
//   - LabelsStorePort:          labels.json アトミック書き込み（仕様書 §10）

// MARK: - SessionListLoaderPort

public protocol SessionListLoaderPort: AnyObject, Sendable {
    /// Documents 配下の `session_*` フォルダ + meta.json を読み込んで返す。
    /// VALID フィルタは UseCase（呼び出し側）で実施する。
    func loadAll() throws -> [(folderName: String, folderURL: URL, meta: MetaJSONPayload)]
}

// MARK: - IMUWaveformLoaderPort

public protocol IMUWaveformLoaderPort: AnyObject, Sendable {
    /// セッションフォルダ内の `imu.csv` を読み込み、波形サンプル列を返す。
    func load(fromFolder folder: URL) throws -> [IMUWaveformSample]
}

// MARK: - LabelsStorePort

public protocol LabelsStorePort: AnyObject, Sendable {
    /// `labels.json.tmp` に書き込み → `FileManager.replaceItemAt` で `labels.json` に rename。
    /// 仕様書 §10「アトミック書き込み」。
    func writeLabelsJSON(_ payload: LabelsJSONPayload, to folder: URL) throws
}
