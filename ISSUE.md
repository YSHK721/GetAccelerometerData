# Issue 管理

本ファイルは `GetAccelerometerData` プロジェクトの Issue を一元管理する。

- ステータス：`OPEN` / `IN_PROGRESS` / `RESOLVED` / `WONTFIX`
- 重大度：`Critical` / `High` / `Medium` / `Low`
- 連番ルール：`ISSUE-001` から開始、新規発生時に +1
- 発行根拠：2026-05-31 のアーキテクチャ精査（メイン会話 + `architecture-executor` サブエージェントの独立評価が一致した確定項目）

---

## ISSUE-001

| 項目 | 内容 |
|---|---|
| 概要 | `AccelerometerManager` の God Object 化（1492 行・6 フレームワーク同時 import） |
| カテゴリ | アーキテクチャ / SRP |
| 重大度 | Critical |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData Watch App/AccelerometerManager.swift` |
| 詳細 | 単一クラスが CoreMotion / HealthKit / WatchConnectivity / WatchKit / Combine / Foundation の 6 フレームワークを同時 import し、センサ取得・記録・転送・ファイル保存・ワークアウト管理・テスト DI を全て担っていた |
| 実施内容 | (1) `WorkoutSessionGateway.swift` を新設、HKHealthStore / HKWorkoutSession / HKLiveWorkoutBuilder を隔離（HealthKit import を Manager から除去）、(2) `SensorDataRepository.swift` を新設、CSV ファイル書き出し（FileManager + 文字列構築）を隔離、(3) `SensorRecords.swift` を新設後 SensorDataKit に統合、`AccelerometerRecord` / `GyroscopeRecord` / `CombinedSensorData` をネストからトップレベル / 共通パッケージへ昇格、(4) `CSVTimestampFormatter` を SensorDataKit に分離（マイクロ秒精度の static フォーマッタ）、(5) `AccelerometerManager` 内の Hybrid Transfer Extension（197 行）／Long Recording Enhancement Extension（198 行）／テスト DI（25 行）／TestableHybridTransferManager Protocol を削除（ISSUE-002 / 008 と連動）。残責務は CoreMotion + WCSession + UI 状態オーケストレーションで、AccelerometerManager は **1452 行 → 805 行（45% 縮小、HealthKit import 除去）** |
| 検証結果 | iOS / Watch 両ターゲット BUILD SUCCEEDED（clean build） |
| 残課題 | CoreMotion 分離（`MotionDataSource`）/ WCSession 分離（`SensorTransferGateway`）は @Published 状態への密結合があるため次回イテレーションで実施 |

---

## ISSUE-002

| 項目 | 内容 |
|---|---|
| 概要 | `HybridTransferManager` クラスが本番未使用、同等ロジックが `AccelerometerManager` extension に二重実装 |
| カテゴリ | YAGNI / DRY / 死蔵抽象 |
| 重大度 | Critical |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData Watch App/HybridTransferManager.swift`（削除）／`AccelerometerManager.swift` の旧 L1003-1397 |
| 詳細 | `HybridTransferManager` クラスが本番経路で一度も init されず、`AccelerometerManager` の Hybrid Transfer Extension / Long Recording Enhancement Extension 内に同等の selectOptimalStrategy / chunkData / transferRealtimeBuffer / fallbackToLocalStorage 等が重複定義されていた。さらに ContentView からも extension メソッドは一度も呼ばれていない完全な死コードだった |
| 実施内容 | (1) `HybridTransferManager.swift`（757 行）を完全削除、(2) `AccelerometerManager` の 2 つの extension ブロック（合計約 395 行）を削除、(3) 関連 @Published（`currentTransferStrategy` / `realtimeBufferCount` / `queuedTransferCount` / `lastTransferTime`）と内部バッファ（`realtimeBuffer` / `pendingTransferData`）を撤去、(4) 削除に伴って参照不能となるテスト 6 ファイル（`HybridTransferBasicTests` / `HybridTransferIntegrationTests` / `HybridTransferManagerTests` / `AccelerometerManagerIntegrationTests` / `LongRecordingValidationTests` / `WatchAppFileSizeTests`）を削除 |
| 承認要否 | 要 → ユーザー本会話で「全て承認」明示済（Q1 承認） |
| 検証結果 | Watch ターゲット BUILD SUCCEEDED。WatchAppLargeFileTransferTests（本番 PayloadSizeValidator を検証）は保持 |

---

## ISSUE-003

| 項目 | 内容 |
|---|---|
| 概要 | iOS `WatchSessionManager` が `ContentView.swift` 内に同居（300 行） |
| カテゴリ | アーキテクチャ / レイヤー違反 |
| 重大度 | Critical |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData/Data/Gateways/WatchSessionGateway.swift`（新設）／`GetAccelerometerData/ContentView.swift`（縮小） |
| 詳細 | WCSessionDelegate 実装・JSON デコード・CSV 変換・ファイル I/O・タイムスタンプフォーマットを 1 クラスで担い、View ファイルに同居していた |
| 実施内容 | `Data/Gateways/WatchSessionGateway.swift` を新設し `WatchSessionManager` クラス本体を移動。ContentView は 670 行 → 351 行に縮小。公開 API（`isSessionReachable` / `allReceivedFiles` / `activateSession` / `getFileDate` 等）は変更せず ContentView 側は無修正。CombinedSensorData / AccelerometerRecord ネスト型は SensorDataKit パッケージの公開型に置換（ISSUE-015 と連動） |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED |

---

## ISSUE-004

| 項目 | 内容 |
|---|---|
| 概要 | Composition Root が `UnifiedAccelerometerChartView.init` に漏出している |
| カテゴリ | アーキテクチャ / DIP |
| 重大度 | Critical |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData/AppComposition.swift`（新設）／`GetAccelerometerData/GetAccelerometerDataApp.swift`／`GetAccelerometerData/Presentation/Views/Charts/UnifiedAccelerometerChartView.swift` |
| 詳細 | View 層の `init` 内で `AccelerometerDataRepository()` を直接生成し、UseCase をインスタンス化していた |
| 実施内容 | (1) `AppComposition.swift` を新設し、Repository → UseCase の生成を一元管理する Sendable struct を定義、(2) `EnvironmentKey` 経由で SwiftUI Environment に注入、(3) `GetAccelerometerDataApp` で `AppComposition()` を生成して `.environment(\.appComposition, composition)` で配下に伝播、(4) `UnifiedAccelerometerChartView` を Wrapper + 内部 Content 構造に分割し、Environment から UseCase を取得して `UnifiedAccelerometerChartContent.init` に Protocol 注入 |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED。呼び出し側（ContentView / FileDetailView）の API は無変更 |

---

## ISSUE-005

| 項目 | 内容 |
|---|---|
| 概要 | CSV タイムスタンプ規約が 3 箇所に重複実装 |
| カテゴリ | DRY / 仕様分散 |
| 重大度 | High |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `Packages/SensorDataKit/Sources/SensorDataKit/CSVTimestampFormatter.swift`（共通実装の正本） |
| 詳細 | `formatCSVTimestamp` / `parseCSVTimestamp`（マイクロ秒精度）が完全に同一ロジックで 3 重定義されていた（Watch `AccelerometerManager` / iOS `ContentView` / iOS `AccelerometerDataRepository`） |
| 実施内容 | (1) SensorDataKit パッケージ（ISSUE-015）に `CSVTimestampFormatter` enum を Public で定義（`format` / `parseTimeInterval` / `parseDate` の 3 API を提供）、(2) Watch `AccelerometerManager.swift` の重複ロジックを削除し `CSVTimestampFormatter.format` を呼び出すよう変更、(3) iOS `ContentView.swift` の重複ロジックを削除、(4) iOS `AccelerometerDataRepository.swift` の重複 `parseCSVTimestamp` を削除し `CSVTimestampFormatter.parseDate` に置換、(5) iOS Domain 配下の中間ファイルも SensorDataKit に統合済みで削除 |
| 検証結果 | iOS / Watch 両ターゲット BUILD SUCCEEDED |

---

## ISSUE-006

| 項目 | 内容 |
|---|---|
| 概要 | UseCase Protocol が本番経路で型として使われず、DIP が機能していない |
| カテゴリ | アーキテクチャ / DIP / 死蔵抽象 |
| 重大度 | High |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData/Presentation/Views/Charts/UnifiedAccelerometerChartView.swift`／`GetAccelerometerData/AppComposition.swift` |
| 詳細 | `LoadAccelerometerDataUseCaseProtocol` / `CalculateStatisticsUseCaseProtocol` が定義されていたが、View の `init` で具象クラスを直接生成しているため Protocol 経由のテスト差し替えが不可能だった |
| 実施内容 | `AppComposition` が UseCase を Protocol 型（`LoadAccelerometerDataUseCaseProtocol` / `CalculateStatisticsUseCaseProtocol`）で保持し、`UnifiedAccelerometerChartContent.init` も Protocol 型で受け取る形に変更。テスト時は `AppComposition(loadDataUseCase: MockX(), calculateStatisticsUseCase: MockY())` で差し替え可能 |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED |

---

## ISSUE-007

| 項目 | 内容 |
|---|---|
| 概要 | `Models/` ディレクトリ命名と実体の矛盾（View が配置されている） |
| カテゴリ | アーキテクチャ / 命名 |
| 重大度 | High |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData/Presentation/Views/{Charts,Statistics,Export}/`（新設）／`GetAccelerometerData/Models/`（削除） |
| 詳細 | ディレクトリ名 `Models/` に対し、配置されているのは Chart 関連 View 10+ 個（StatisticsView / ExportOptionsView 等）。Entity/Model 用ディレクトリと取り違える危険があった |
| 実施内容 | `Models/AccelerometerChartView.swift`（1280 行）を以下 6 ファイルに分割：(1) `Presentation/Views/Charts/AccelerometerChartComponent.swift`、(2) `Presentation/Views/Charts/UnifiedAccelerometerChartView.swift`（Wrapper + Content + extension）、(3) `Presentation/Views/Charts/ZoomableAccelerometerChartComponent.swift`、(4) `Presentation/Views/Charts/ZoomOverlays.swift`（ZoomHelpOverlay + ZoomStatusOverlay）、(5) `Presentation/Views/Statistics/StatisticsView.swift`（StatisticCard + StatisticsView）、(6) `Presentation/Views/Export/ExportOptionsView.swift`（ExportStatusView + ExportButtonView + ExportOptionsView）。`Models/` ディレクトリは完全削除 |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED |

---

## ISSUE-008

| 項目 | 内容 |
|---|---|
| 概要 | テスト用 DI が型消去 `Any?` で本番クラスに漏出 |
| カテゴリ | アーキテクチャ / テスト容易性 |
| 重大度 | High |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData Watch App/AccelerometerManager.swift` |
| 詳細 | `testTransferManager: Any?` プロパティと `init(testTransferManager: Any)` ／ `startRecording(duration:)` ／ `processDataTransfer(size:)` ／ `handleTransferError()` がテスト目的で本番クラスに公開され、`TestableHybridTransferManager` プロトコルもそのために存在していた |
| 実施内容 | (1) `testTransferManager` プロパティ削除、(2) `init(testTransferManager:)` 削除（`override init()` のみ残置）、(3) `startRecording(duration:)` / `processDataTransfer(size:)` / `handleTransferError()` の 3 つのテスト専用メソッド削除、(4) `TestableHybridTransferManager` プロトコル削除。WorkoutSessionGateway / SensorDataRepository は Protocol ベースで構築されているため将来のテスト時は通常の DI を使用可能 |
| 検証結果 | Watch ターゲット BUILD SUCCEEDED |

---

## ISSUE-009

| 項目 | 内容 |
|---|---|
| 概要 | `applyExporters()` の二重定義（自己言及的死コード） |
| カテゴリ | YAGNI / デッドコード |
| 重大度 | Medium |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | （旧）`GetAccelerometerData/Models/AccelerometerChartView.swift` L745-781 |
| 詳細 | `extension View.applyExporters()` と `extension ExportOptionsView.applyExporters()` が並列定義され、コメントに「コンパイラエラー回避のサンプル」「実際のアプリでは下記を ExportOptionsView に実装してください」と未使用が明記されていた |
| 実施内容 | 両 extension を完全削除 |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED |

---

## ISSUE-010

| 項目 | 内容 |
|---|---|
| 概要 | `formatDuration` がファイル横断で二重定義 |
| カテゴリ | DRY |
| 重大度 | Medium |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData/Presentation/Views/Color+Extensions.swift`（共通拡張に統一）／`GetAccelerometerData/Presentation/ViewModels/AccelerometerChartViewModel.swift`（重複削除）／（旧）`Models/AccelerometerChartView.swift`（重複削除） |
| 詳細 | グローバル関数 `formatDuration(seconds:)` と ViewModel 内 `formatDuration` が同名同実装で 2 重定義されていた |
| 実施内容 | (1) `Color+Extensions.swift` に `extension TimeInterval { var formattedDuration: String }` を追加、(2) View 側 `formatDuration(seconds: x)` 呼び出しを `x.formattedDuration` に変更、(3) グローバル関数 / ViewModel 内重複定義を削除 |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED |

---

## ISSUE-011

| 項目 | 内容 |
|---|---|
| 概要 | Chart の色定義が `chartForegroundStyleScale` でハードコードされ、`Color+Extensions` と二重管理 |
| カテゴリ | DRY / 単一情報源 |
| 重大度 | Medium |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData/Presentation/Views/Color+Extensions.swift`／`GetAccelerometerData/Presentation/Views/Charts/AccelerometerChartComponent.swift`／`GetAccelerometerData/Presentation/Views/Charts/ZoomableAccelerometerChartComponent.swift` |
| 詳細 | `Chart` 内で `["X軸": .blue, "Y軸": .green, ...]` がハードコードされ、`Color.xAxisColor` 等の定義と二重管理だった |
| 実施内容 | (1) `Color+Extensions.swift` に `static let accelerometerLegendColors: KeyValuePairs<String, Color>` を追加（DataType.rawValue → 対応 Color の単一情報源）、(2) `chartForegroundStyleScale([...])` を `chartForegroundStyleScale(Color.accelerometerLegendColors)` に変更（生きている 2 箇所、3 つ目は ISSUE-012 で死コードごと削除済み） |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED |

---

## ISSUE-012

| 項目 | 内容 |
|---|---|
| 概要 | `SelectableAccelerometerChartComponent`（約 245 行）が完全な死コード |
| カテゴリ | YAGNI / デッドコード |
| 重大度 | Medium |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | （旧）`GetAccelerometerData/Models/AccelerometerChartView.swift` L246-490 |
| 詳細 | `UnifiedAccelerometerChartView.chartWithSelection` は `ZoomableAccelerometerChartComponent` を使用しており、`SelectableAccelerometerChartComponent` への参照が存在しなかった |
| 実施内容 | クラス全体（248 行）を削除 |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED |

---

## ISSUE-013

| 項目 | 内容 |
|---|---|
| 概要 | Watch 側 `AccelerometerManager.loadDataFromCSV` が死コード |
| カテゴリ | YAGNI / デッドコード |
| 重大度 | Medium |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData Watch App/AccelerometerManager.swift` |
| 詳細 | Watch UI（`FileDetailView`）は `String(contentsOf:)` で生表示するのみで、`AccelerometerManager.loadDataFromCSV` を呼び出さなかった |
| 実施内容 | 関数本体（38 行）を削除 |
| 検証結果 | Watch ターゲット BUILD SUCCEEDED |

---

## ISSUE-014

| 項目 | 内容 |
|---|---|
| 概要 | `DataExportService.validateCSVFormat` が業務ルールであるにもかかわらず `Utilities/` 配下に配置、かつ旧 5 列 CSV 形式を期待しており現行 9 列形式で機能しない |
| カテゴリ | アーキテクチャ / レイヤー責務違反 |
| 重大度 | High |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData/Domain/UseCases/ValidateSensorCSVUseCase.swift`（新設）／`GetAccelerometerData/Utilities/DataExportService.swift`（縮小） |
| 詳細 | 必須カラム検証・NaN/Infinity 除外・数値解析判定という業務ルールが Utility 層に存在。さらに現行 9 列 CSV（`timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude`）と齟齬があり、旧 5 列形式（`timestamp,x,y,z,magnitude`）のみを許可していた |
| 実施内容 | (1) `Domain/UseCases/ValidateSensorCSVUseCase.swift` を新設し業務ルール（必須カラム / 数値妥当性 / 行数チェック / NaN・Infinity 拒否）を移管、(2) 現行 9 列フォーマットと旧 5 列フォーマットの両方を許可するよう拡張、(3) `DataExportService.prepareCSVForExport` を UseCase 委譲に変更、(4) 旧 `validateCSVFormat` 静的メソッド（120 行）を削除 |
| 検証結果 | iOS ターゲット BUILD SUCCEEDED |

---

## ISSUE-015

| 項目 | 内容 |
|---|---|
| 概要 | iOS / Watch 間で Domain Entity が独立定義され重複している |
| カテゴリ | アーキテクチャ / Domain 統一 |
| 重大度 | High |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `Packages/SensorDataKit/Package.swift`（新設）／`Packages/SensorDataKit/Sources/SensorDataKit/{CSVTimestampFormatter,SensorRecords}.swift`（新設）／`GetAccelerometerData.xcodeproj/project.pbxproj`（Local Package 統合） |
| 詳細 | センサ値を表す Entity が `AccelerometerReading`（iOS Domain）・`AccelerometerRecord`（Watch nested）・`GyroscopeRecord`（Watch nested）・`CombinedSensorData`（iOS と Watch で別定義）と 5 種類分散していた |
| 実施内容 | (1) `Packages/SensorDataKit/` に Local Swift Package を新設（Swift 6.0 / iOS 17 / watchOS 10）、(2) Public API として `CSVTimestampFormatter` enum と `AccelerometerRecord` / `GyroscopeRecord` / `CombinedSensorData` の Sendable / Codable / Equatable 構造体を公開、(3) `project.pbxproj` を Python スクリプトで自動編集し、`PBXFileReference` / `XCLocalSwiftPackageReference` / `XCSwiftPackageProductDependency` ×2（iOS + Watch）/ `PBXBuildFile` ×2 / `packageReferences` / 両ターゲットの `packageProductDependencies` / Frameworks ビルドフェーズへの登録を全て追加、(4) Watch / iOS 両ターゲットの重複ファイル（`GetAccelerometerData Watch App/CSVTimestampFormatter.swift` / `SensorRecords.swift` / `GetAccelerometerData/Domain/Entities/CSVTimestampFormatter.swift`）を削除、(5) iOS `WatchSessionGateway` のネスト型 `CombinedSensorData` / `AccelerometerRecord` を撤去し SensorDataKit 公開型を再利用、(6) 該当 4 ファイル（iOS AccelerometerDataRepository / WatchSessionGateway / Watch AccelerometerManager / Watch SensorDataRepository）に `import SensorDataKit` を追加 |
| 承認要否 | 要 → ユーザー本会話で「全て承認」明示済（Q3 承認） |
| バックアップ | `GetAccelerometerData.xcodeproj/project.pbxproj.bak.20260531_phaseE` |
| 検証結果 | iOS / Watch 両ターゲット clean build SUCCEEDED |

---

## ISSUE-016

| 項目 | 内容 |
|---|---|
| 概要 | Swift 言語モードを 5.0 → 6.0 に移行（ユーザー指示） |
| カテゴリ | 技術スタック / 並行性安全 |
| 重大度 | High |
| ステータス | RESOLVED |
| 発見日 | 2026-05-31 |
| 解決日 | 2026-05-31 |
| 該当ファイル | `GetAccelerometerData.xcodeproj/project.pbxproj`（20 箇所）／`GetAccelerometerData Watch App/HybridTransferManager.swift`／`GetAccelerometerData Watch App/AccelerometerManager.swift`／`GetAccelerometerData/ContentView.swift`／`GetAccelerometerData/Domain/Entities/{AccelerometerReading,DataStatistics,DataType}.swift`／`GetAccelerometerData/Domain/Repositories/AccelerometerDataRepositoryProtocol.swift`／`GetAccelerometerData/Domain/UseCases/{LoadAccelerometerDataUseCase,CalculateStatisticsUseCase}.swift` |
| 詳細 | Xcode 26.5 / Swift 6.3.2 環境下で言語モードを 6.0 に切替。Strict Concurrency Checking が有効化され、合計約 70 件のコンパイルエラーが発生した |
| 実施内容 | (1) pbxproj の `SWIFT_VERSION = 5.0;` 20 箇所を `6.0;` に一括置換、(2) `HybridTransferManagerProtocol` / `HybridTransferManager` クラスに `@MainActor` 付与、(3) `AccelerometerManager`（Watch）に `@MainActor` 付与＋`WCSessionDelegate` 2 メソッドを `nonisolated` 化、(4) `WatchSessionManager`（iOS）に `@MainActor` 付与＋`WCSessionDelegate` 8 メソッドを `nonisolated` 化、(5) `convertCombinedDataToCSV` / `convertRecordsToCSV` を `nonisolated` 化、(6) `formatCSVTimestamp` を `nonisolated` 化＋静的 DateFormatter を `nonisolated(unsafe)` 化、(7) `lastReceivedMetadata` を `[String: Any]` → `[String: String]` 型変更＋`Task { @MainActor in ... }` / `MainActor.assumeIsolated` 経由でアクセス、(8) WCSession デリゲート内で `session.isReachable` を `nonisolated` コンテキスト側で事前取得して `Sendable` Bool として渡す、(9) `AccelerometerDataRepositoryProtocol` / `LoadAccelerometerDataUseCaseProtocol` / `CalculateStatisticsUseCaseProtocol` に `Sendable` 適合、(10) `AccelerometerReading` / `DataStatistics` / `DataType` に `Sendable` 適合、(11) UseCase 実装クラスを `final class` 化 |
| 承認要否 | 要（CLAUDE.md「技術スタックのバージョン変更」承認対象）→ ユーザー本会話で明示承認済 |
| バックアップ | `GetAccelerometerData.xcodeproj/project.pbxproj.bak.20260531` |
| 検証結果 | iOS ターゲット（iPhone 17 Pro / OS 26.5）：BUILD SUCCEEDED ／ Watch ターゲット（Apple Watch Series 10 46mm）：BUILD SUCCEEDED |
| 残課題 | (a) `nonisolated(unsafe)` を使った静的 DateFormatter は ISSUE-015 完了に伴い SensorDataKit パッケージで `DateFormatter is Sendable` 推論が効くため不要に解消済、(b) `MainActor.assumeIsolated` は WCSession デリゲートが Main thread で呼ばれることへの暗黙依存を持つ。ISSUE-001 完了に伴う `WatchSessionGateway` 分離（Phase E）で観測表面は縮小したが、引き続き次回イテレーションで再設計を検討 |

---

## 集計（2026-05-31 最終更新）

| 重大度 | 件数 | 番号 |
|---|---|---|
| Critical | 4 | ISSUE-001, 002, 003, 004 |
| High | 7 | ISSUE-005, 006, 007, 008, 014, 015, 016 |
| Medium | 5 | ISSUE-009, 010, 011, 012, 013 |
| Low | 0 | — |
| **合計** | **16** | **ISSUE-001 〜 ISSUE-016** |

### ステータス内訳

| ステータス | 件数 | 番号 |
|---|---|---|
| OPEN | 0 | — |
| IN_PROGRESS | 0 | — |
| RESOLVED | 16 | ISSUE-001 〜 016 |
| WONTFIX | 0 | — |

### 完了概要

- **削除されたコード**: HybridTransferManager.swift（757 行）+ 6 死コードテスト（約 1700 行）+ AccelerometerManager 内拡張・テスト DI（約 400 行）+ SelectableAccelerometerChartComponent（248 行）+ 各種重複コード = **合計約 3100 行削減**
- **新設されたファイル**: 16 ファイル（SensorDataKit Package 含む）
- **削除されたディレクトリ**: `GetAccelerometerData/Models/`（命名矛盾解消）
- **追加されたモジュール**: `SensorDataKit` Local Swift Package（iOS / watchOS 共通の Domain）
- **最終ビルド検証**: iOS（iPhone 17 / OS 26.5）/ watchOS（Apple Watch Series 11 / OS 26.5）両ターゲット clean build SUCCEEDED

### 次回イテレーション候補

| カテゴリ | 内容 |
|---|---|
| AccelerometerManager 残責務分離 | `MotionDataSource`（CoreMotion 隔離）/ `SensorTransferGateway`（WCSession 隔離）の追加抽出 |
| WatchSessionGateway 再設計 | `MainActor.assumeIsolated` 依存を解消する明示的 actor 設計 |
| テストカバレッジ復旧 | 削除されたテストの代わりに、Protocol 化された UseCase / Gateway に対する単体テストを再構築 |
| AppDependencies の Watch 対応 | Watch アプリ側の Composition Root（現状 `AccelerometerManager()` 直接生成）を AppComposition 相当の構造に統一 |
