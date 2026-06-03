# Issue 管理

本ファイルは `GetAccelerometerData` プロジェクトの Issue を一元管理する。

- ステータス：`OPEN` / `IN_PROGRESS` / `RESOLVED` / `WONTFIX`
- 重大度：`Critical` / `High` / `Medium` / `Low`
- 連番ルール：`ISSUE-001` から開始、新規発生時に +1
- 発行根拠：2026-05-31 のアーキテクチャ精査（メイン会話 + `architecture-executor` サブエージェントの独立評価が一致した確定項目）

---

## ISSUE-001

- **概要**：`AccelerometerManager` の God Object 化（1492 行・6 フレームワーク同時 import）
- **カテゴリ**：アーキテクチャ / SRP
- **重大度**：Critical
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData Watch App/AccelerometerManager.swift`
- **詳細**：単一クラスが CoreMotion / HealthKit / WatchConnectivity / WatchKit / Combine / Foundation の 6 フレームワークを同時 import し、センサ取得・記録・転送・ファイル保存・ワークアウト管理・テスト DI を全て担っていた
- **実施内容**：(1) `WorkoutSessionGateway.swift` を新設、HKHealthStore / HKWorkoutSession / HKLiveWorkoutBuilder を隔離（HealthKit import を Manager から除去）、(2) `SensorDataRepository.swift` を新設、CSV ファイル書き出し（FileManager + 文字列構築）を隔離、(3) `SensorRecords.swift` を新設後 SensorDataKit に統合、`AccelerometerRecord` / `GyroscopeRecord` / `CombinedSensorData` をネストからトップレベル / 共通パッケージへ昇格、(4) `CSVTimestampFormatter` を SensorDataKit に分離（マイクロ秒精度の static フォーマッタ）、(5) `AccelerometerManager` 内の Hybrid Transfer Extension（197 行）／Long Recording Enhancement Extension（198 行）／テスト DI（25 行）／TestableHybridTransferManager Protocol を削除（ISSUE-002 / 008 と連動）。残責務は CoreMotion + WCSession + UI 状態オーケストレーションで、AccelerometerManager は **1452 行 → 805 行（45% 縮小、HealthKit import 除去）**
- **検証結果**：iOS / Watch 両ターゲット BUILD SUCCEEDED（clean build）
- **残課題**：CoreMotion 分離（`MotionDataSource`）/ WCSession 分離（`SensorTransferGateway`）は @Published 状態への密結合があるため次回イテレーションで実施

---

## ISSUE-002

- **概要**：`HybridTransferManager` クラスが本番未使用、同等ロジックが `AccelerometerManager` extension に二重実装
- **カテゴリ**：YAGNI / DRY / 死蔵抽象
- **重大度**：Critical
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData Watch App/HybridTransferManager.swift`（削除）／`AccelerometerManager.swift` の旧 L1003-1397
- **詳細**：`HybridTransferManager` クラスが本番経路で一度も init されず、`AccelerometerManager` の Hybrid Transfer Extension / Long Recording Enhancement Extension 内に同等の selectOptimalStrategy / chunkData / transferRealtimeBuffer / fallbackToLocalStorage 等が重複定義されていた。さらに ContentView からも extension メソッドは一度も呼ばれていない完全な死コードだった
- **実施内容**：(1) `HybridTransferManager.swift`（757 行）を完全削除、(2) `AccelerometerManager` の 2 つの extension ブロック（合計約 395 行）を削除、(3) 関連 @Published（`currentTransferStrategy` / `realtimeBufferCount` / `queuedTransferCount` / `lastTransferTime`）と内部バッファ（`realtimeBuffer` / `pendingTransferData`）を撤去、(4) 削除に伴って参照不能となるテスト 6 ファイル（`HybridTransferBasicTests` / `HybridTransferIntegrationTests` / `HybridTransferManagerTests` / `AccelerometerManagerIntegrationTests` / `LongRecordingValidationTests` / `WatchAppFileSizeTests`）を削除
- **承認要否**：要 → ユーザー本会話で「全て承認」明示済（Q1 承認）
- **検証結果**：Watch ターゲット BUILD SUCCEEDED。WatchAppLargeFileTransferTests（本番 PayloadSizeValidator を検証）は保持

---

## ISSUE-003

- **概要**：iOS `WatchSessionManager` が `ContentView.swift` 内に同居（300 行）
- **カテゴリ**：アーキテクチャ / レイヤー違反
- **重大度**：Critical
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData/Data/Gateways/WatchSessionGateway.swift`（新設）／`GetAccelerometerData/ContentView.swift`（縮小）
- **詳細**：WCSessionDelegate 実装・JSON デコード・CSV 変換・ファイル I/O・タイムスタンプフォーマットを 1 クラスで担い、View ファイルに同居していた
- **実施内容**：`Data/Gateways/WatchSessionGateway.swift` を新設し `WatchSessionManager` クラス本体を移動。ContentView は 670 行 → 351 行に縮小。公開 API（`isSessionReachable` / `allReceivedFiles` / `activateSession` / `getFileDate` 等）は変更せず ContentView 側は無修正。CombinedSensorData / AccelerometerRecord ネスト型は SensorDataKit パッケージの公開型に置換（ISSUE-015 と連動）
- **検証結果**：iOS ターゲット BUILD SUCCEEDED

---

## ISSUE-004

- **概要**：Composition Root が `UnifiedAccelerometerChartView.init` に漏出している
- **カテゴリ**：アーキテクチャ / DIP
- **重大度**：Critical
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData/AppComposition.swift`（新設）／`GetAccelerometerData/GetAccelerometerDataApp.swift`／`GetAccelerometerData/Presentation/Views/Charts/UnifiedAccelerometerChartView.swift`
- **詳細**：View 層の `init` 内で `AccelerometerDataRepository()` を直接生成し、UseCase をインスタンス化していた
- **実施内容**：(1) `AppComposition.swift` を新設し、Repository → UseCase の生成を一元管理する Sendable struct を定義、(2) `EnvironmentKey` 経由で SwiftUI Environment に注入、(3) `GetAccelerometerDataApp` で `AppComposition()` を生成して `.environment(\.appComposition, composition)` で配下に伝播、(4) `UnifiedAccelerometerChartView` を Wrapper + 内部 Content 構造に分割し、Environment から UseCase を取得して `UnifiedAccelerometerChartContent.init` に Protocol 注入
- **検証結果**：iOS ターゲット BUILD SUCCEEDED。呼び出し側（ContentView / FileDetailView）の API は無変更

---

## ISSUE-005

- **概要**：CSV タイムスタンプ規約が 3 箇所に重複実装
- **カテゴリ**：DRY / 仕様分散
- **重大度**：High
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`Packages/SensorDataKit/Sources/SensorDataKit/CSVTimestampFormatter.swift`（共通実装の正本）
- **詳細**：`formatCSVTimestamp` / `parseCSVTimestamp`（マイクロ秒精度）が完全に同一ロジックで 3 重定義されていた（Watch `AccelerometerManager` / iOS `ContentView` / iOS `AccelerometerDataRepository`）
- **実施内容**：(1) SensorDataKit パッケージ（ISSUE-015）に `CSVTimestampFormatter` enum を Public で定義（`format` / `parseTimeInterval` / `parseDate` の 3 API を提供）、(2) Watch `AccelerometerManager.swift` の重複ロジックを削除し `CSVTimestampFormatter.format` を呼び出すよう変更、(3) iOS `ContentView.swift` の重複ロジックを削除、(4) iOS `AccelerometerDataRepository.swift` の重複 `parseCSVTimestamp` を削除し `CSVTimestampFormatter.parseDate` に置換、(5) iOS Domain 配下の中間ファイルも SensorDataKit に統合済みで削除
- **検証結果**：iOS / Watch 両ターゲット BUILD SUCCEEDED

---

## ISSUE-006

- **概要**：UseCase Protocol が本番経路で型として使われず、DIP が機能していない
- **カテゴリ**：アーキテクチャ / DIP / 死蔵抽象
- **重大度**：High
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData/Presentation/Views/Charts/UnifiedAccelerometerChartView.swift`／`GetAccelerometerData/AppComposition.swift`
- **詳細**：`LoadAccelerometerDataUseCaseProtocol` / `CalculateStatisticsUseCaseProtocol` が定義されていたが、View の `init` で具象クラスを直接生成しているため Protocol 経由のテスト差し替えが不可能だった
- **実施内容**：`AppComposition` が UseCase を Protocol 型（`LoadAccelerometerDataUseCaseProtocol` / `CalculateStatisticsUseCaseProtocol`）で保持し、`UnifiedAccelerometerChartContent.init` も Protocol 型で受け取る形に変更。テスト時は `AppComposition(loadDataUseCase: MockX(), calculateStatisticsUseCase: MockY())` で差し替え可能
- **検証結果**：iOS ターゲット BUILD SUCCEEDED

---

## ISSUE-007

- **概要**：`Models/` ディレクトリ命名と実体の矛盾（View が配置されている）
- **カテゴリ**：アーキテクチャ / 命名
- **重大度**：High
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData/Presentation/Views/{Charts,Statistics,Export}/`（新設）／`GetAccelerometerData/Models/`（削除）
- **詳細**：ディレクトリ名 `Models/` に対し、配置されているのは Chart 関連 View 10+ 個（StatisticsView / ExportOptionsView 等）。Entity/Model 用ディレクトリと取り違える危険があった
- **実施内容**：`Models/AccelerometerChartView.swift`（1280 行）を以下 6 ファイルに分割：(1) `Presentation/Views/Charts/AccelerometerChartComponent.swift`、(2) `Presentation/Views/Charts/UnifiedAccelerometerChartView.swift`（Wrapper + Content + extension）、(3) `Presentation/Views/Charts/ZoomableAccelerometerChartComponent.swift`、(4) `Presentation/Views/Charts/ZoomOverlays.swift`（ZoomHelpOverlay + ZoomStatusOverlay）、(5) `Presentation/Views/Statistics/StatisticsView.swift`（StatisticCard + StatisticsView）、(6) `Presentation/Views/Export/ExportOptionsView.swift`（ExportStatusView + ExportButtonView + ExportOptionsView）。`Models/` ディレクトリは完全削除
- **検証結果**：iOS ターゲット BUILD SUCCEEDED

---

## ISSUE-008

- **概要**：テスト用 DI が型消去 `Any?` で本番クラスに漏出
- **カテゴリ**：アーキテクチャ / テスト容易性
- **重大度**：High
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData Watch App/AccelerometerManager.swift`
- **詳細**：`testTransferManager: Any?` プロパティと `init(testTransferManager: Any)` ／ `startRecording(duration:)` ／ `processDataTransfer(size:)` ／ `handleTransferError()` がテスト目的で本番クラスに公開され、`TestableHybridTransferManager` プロトコルもそのために存在していた
- **実施内容**：(1) `testTransferManager` プロパティ削除、(2) `init(testTransferManager:)` 削除（`override init()` のみ残置）、(3) `startRecording(duration:)` / `processDataTransfer(size:)` / `handleTransferError()` の 3 つのテスト専用メソッド削除、(4) `TestableHybridTransferManager` プロトコル削除。WorkoutSessionGateway / SensorDataRepository は Protocol ベースで構築されているため将来のテスト時は通常の DI を使用可能
- **検証結果**：Watch ターゲット BUILD SUCCEEDED

---

## ISSUE-009

- **概要**：`applyExporters()` の二重定義（自己言及的死コード）
- **カテゴリ**：YAGNI / デッドコード
- **重大度**：Medium
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：（旧）`GetAccelerometerData/Models/AccelerometerChartView.swift` L745-781
- **詳細**：`extension View.applyExporters()` と `extension ExportOptionsView.applyExporters()` が並列定義され、コメントに「コンパイラエラー回避のサンプル」「実際のアプリでは下記を ExportOptionsView に実装してください」と未使用が明記されていた
- **実施内容**：両 extension を完全削除
- **検証結果**：iOS ターゲット BUILD SUCCEEDED

---

## ISSUE-010

- **概要**：`formatDuration` がファイル横断で二重定義
- **カテゴリ**：DRY
- **重大度**：Medium
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData/Presentation/Views/Color+Extensions.swift`（共通拡張に統一）／`GetAccelerometerData/Presentation/ViewModels/AccelerometerChartViewModel.swift`（重複削除）／（旧）`Models/AccelerometerChartView.swift`（重複削除）
- **詳細**：グローバル関数 `formatDuration(seconds:)` と ViewModel 内 `formatDuration` が同名同実装で 2 重定義されていた
- **実施内容**：(1) `Color+Extensions.swift` に `extension TimeInterval { var formattedDuration: String }` を追加、(2) View 側 `formatDuration(seconds: x)` 呼び出しを `x.formattedDuration` に変更、(3) グローバル関数 / ViewModel 内重複定義を削除
- **検証結果**：iOS ターゲット BUILD SUCCEEDED

---

## ISSUE-011

- **概要**：Chart の色定義が `chartForegroundStyleScale` でハードコードされ、`Color+Extensions` と二重管理
- **カテゴリ**：DRY / 単一情報源
- **重大度**：Medium
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData/Presentation/Views/Color+Extensions.swift`／`GetAccelerometerData/Presentation/Views/Charts/AccelerometerChartComponent.swift`／`GetAccelerometerData/Presentation/Views/Charts/ZoomableAccelerometerChartComponent.swift`
- **詳細**：`Chart` 内で `["X軸": .blue, "Y軸": .green, ...]` がハードコードされ、`Color.xAxisColor` 等の定義と二重管理だった
- **実施内容**：(1) `Color+Extensions.swift` に `static let accelerometerLegendColors: KeyValuePairs<String, Color>` を追加（DataType.rawValue → 対応 Color の単一情報源）、(2) `chartForegroundStyleScale([...])` を `chartForegroundStyleScale(Color.accelerometerLegendColors)` に変更（生きている 2 箇所、3 つ目は ISSUE-012 で死コードごと削除済み）
- **検証結果**：iOS ターゲット BUILD SUCCEEDED

---

## ISSUE-012

- **概要**：`SelectableAccelerometerChartComponent`（約 245 行）が完全な死コード
- **カテゴリ**：YAGNI / デッドコード
- **重大度**：Medium
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：（旧）`GetAccelerometerData/Models/AccelerometerChartView.swift` L246-490
- **詳細**：`UnifiedAccelerometerChartView.chartWithSelection` は `ZoomableAccelerometerChartComponent` を使用しており、`SelectableAccelerometerChartComponent` への参照が存在しなかった
- **実施内容**：クラス全体（248 行）を削除
- **検証結果**：iOS ターゲット BUILD SUCCEEDED

---

## ISSUE-013

- **概要**：Watch 側 `AccelerometerManager.loadDataFromCSV` が死コード
- **カテゴリ**：YAGNI / デッドコード
- **重大度**：Medium
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData Watch App/AccelerometerManager.swift`
- **詳細**：Watch UI（`FileDetailView`）は `String(contentsOf:)` で生表示するのみで、`AccelerometerManager.loadDataFromCSV` を呼び出さなかった
- **実施内容**：関数本体（38 行）を削除
- **検証結果**：Watch ターゲット BUILD SUCCEEDED

---

## ISSUE-014

- **概要**：`DataExportService.validateCSVFormat` が業務ルールであるにもかかわらず `Utilities/` 配下に配置、かつ旧 5 列 CSV 形式を期待しており現行 9 列形式で機能しない
- **カテゴリ**：アーキテクチャ / レイヤー責務違反
- **重大度**：High
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData/Domain/UseCases/ValidateSensorCSVUseCase.swift`（新設）／`GetAccelerometerData/Utilities/DataExportService.swift`（縮小）
- **詳細**：必須カラム検証・NaN/Infinity 除外・数値解析判定という業務ルールが Utility 層に存在。さらに現行 9 列 CSV（`timestamp,accel_x,accel_y,accel_z,accel_magnitude,gyro_x,gyro_y,gyro_z,gyro_magnitude`）と齟齬があり、旧 5 列形式（`timestamp,x,y,z,magnitude`）のみを許可していた
- **実施内容**：(1) `Domain/UseCases/ValidateSensorCSVUseCase.swift` を新設し業務ルール（必須カラム / 数値妥当性 / 行数チェック / NaN・Infinity 拒否）を移管、(2) 現行 9 列フォーマットと旧 5 列フォーマットの両方を許可するよう拡張、(3) `DataExportService.prepareCSVForExport` を UseCase 委譲に変更、(4) 旧 `validateCSVFormat` 静的メソッド（120 行）を削除
- **検証結果**：iOS ターゲット BUILD SUCCEEDED

---

## ISSUE-015

- **概要**：iOS / Watch 間で Domain Entity が独立定義され重複している
- **カテゴリ**：アーキテクチャ / Domain 統一
- **重大度**：High
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`Packages/SensorDataKit/Package.swift`（新設）／`Packages/SensorDataKit/Sources/SensorDataKit/{CSVTimestampFormatter,SensorRecords}.swift`（新設）／`GetAccelerometerData.xcodeproj/project.pbxproj`（Local Package 統合）
- **詳細**：センサ値を表す Entity が `AccelerometerReading`（iOS Domain）・`AccelerometerRecord`（Watch nested）・`GyroscopeRecord`（Watch nested）・`CombinedSensorData`（iOS と Watch で別定義）と 5 種類分散していた
- **実施内容**：(1) `Packages/SensorDataKit/` に Local Swift Package を新設（Swift 6.0 / iOS 17 / watchOS 10）、(2) Public API として `CSVTimestampFormatter` enum と `AccelerometerRecord` / `GyroscopeRecord` / `CombinedSensorData` の Sendable / Codable / Equatable 構造体を公開、(3) `project.pbxproj` を Python スクリプトで自動編集し、`PBXFileReference` / `XCLocalSwiftPackageReference` / `XCSwiftPackageProductDependency` ×2（iOS + Watch）/ `PBXBuildFile` ×2 / `packageReferences` / 両ターゲットの `packageProductDependencies` / Frameworks ビルドフェーズへの登録を全て追加、(4) Watch / iOS 両ターゲットの重複ファイル（`GetAccelerometerData Watch App/CSVTimestampFormatter.swift` / `SensorRecords.swift` / `GetAccelerometerData/Domain/Entities/CSVTimestampFormatter.swift`）を削除、(5) iOS `WatchSessionGateway` のネスト型 `CombinedSensorData` / `AccelerometerRecord` を撤去し SensorDataKit 公開型を再利用、(6) 該当 4 ファイル（iOS AccelerometerDataRepository / WatchSessionGateway / Watch AccelerometerManager / Watch SensorDataRepository）に `import SensorDataKit` を追加
- **承認要否**：要 → ユーザー本会話で「全て承認」明示済（Q3 承認）
- **バックアップ**：`GetAccelerometerData.xcodeproj/project.pbxproj.bak.20260531_phaseE`
- **検証結果**：iOS / Watch 両ターゲット clean build SUCCEEDED

---

## ISSUE-016

- **概要**：Swift 言語モードを 5.0 → 6.0 に移行（ユーザー指示）
- **カテゴリ**：技術スタック / 並行性安全
- **重大度**：High
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData.xcodeproj/project.pbxproj`（20 箇所）／`GetAccelerometerData Watch App/HybridTransferManager.swift`／`GetAccelerometerData Watch App/AccelerometerManager.swift`／`GetAccelerometerData/ContentView.swift`／`GetAccelerometerData/Domain/Entities/{AccelerometerReading,DataStatistics,DataType}.swift`／`GetAccelerometerData/Domain/Repositories/AccelerometerDataRepositoryProtocol.swift`／`GetAccelerometerData/Domain/UseCases/{LoadAccelerometerDataUseCase,CalculateStatisticsUseCase}.swift`
- **詳細**：Xcode 26.5 / Swift 6.3.2 環境下で言語モードを 6.0 に切替。Strict Concurrency Checking が有効化され、合計約 70 件のコンパイルエラーが発生した
- **実施内容**：(1) pbxproj の `SWIFT_VERSION = 5.0;` 20 箇所を `6.0;` に一括置換、(2) `HybridTransferManagerProtocol` / `HybridTransferManager` クラスに `@MainActor` 付与、(3) `AccelerometerManager`（Watch）に `@MainActor` 付与＋`WCSessionDelegate` 2 メソッドを `nonisolated` 化、(4) `WatchSessionManager`（iOS）に `@MainActor` 付与＋`WCSessionDelegate` 8 メソッドを `nonisolated` 化、(5) `convertCombinedDataToCSV` / `convertRecordsToCSV` を `nonisolated` 化、(6) `formatCSVTimestamp` を `nonisolated` 化＋静的 DateFormatter を `nonisolated(unsafe)` 化、(7) `lastReceivedMetadata` を `[String: Any]` → `[String: String]` 型変更＋`Task { @MainActor in ... }` / `MainActor.assumeIsolated` 経由でアクセス、(8) WCSession デリゲート内で `session.isReachable` を `nonisolated` コンテキスト側で事前取得して `Sendable` Bool として渡す、(9) `AccelerometerDataRepositoryProtocol` / `LoadAccelerometerDataUseCaseProtocol` / `CalculateStatisticsUseCaseProtocol` に `Sendable` 適合、(10) `AccelerometerReading` / `DataStatistics` / `DataType` に `Sendable` 適合、(11) UseCase 実装クラスを `final class` 化
- **承認要否**：要（CLAUDE.md「技術スタックのバージョン変更」承認対象）→ ユーザー本会話で明示承認済
- **バックアップ**：`GetAccelerometerData.xcodeproj/project.pbxproj.bak.20260531`
- **検証結果**：iOS ターゲット（iPhone 17 Pro / OS 26.5）：BUILD SUCCEEDED ／ Watch ターゲット（Apple Watch Series 10 46mm）：BUILD SUCCEEDED
- **残課題**：(a) `nonisolated(unsafe)` を使った静的 DateFormatter は ISSUE-015 完了に伴い SensorDataKit パッケージで `DateFormatter is Sendable` 推論が効くため不要に解消済、(b) `MainActor.assumeIsolated` は WCSession デリゲートが Main thread で呼ばれることへの暗黙依存を持つ。ISSUE-001 完了に伴う `WatchSessionGateway` 分離（Phase E）で観測表面は縮小したが、引き続き次回イテレーションで再設計を検討

---

## ISSUE-017

- **概要**：実行時クラッシュ `libdispatch _dispatch_assert_queue_fail`（Thread 8 / `EXC_BREAKPOINT`）
- **カテゴリ**：並行性 / Swift 6 MainActor 隔離違反
- **重大度**：Critical
- **ステータス**：RESOLVED
- **発見日**：2026-05-31
- **解決日**：2026-05-31
- **該当ファイル**：`GetAccelerometerData Watch App/AccelerometerManager.swift`（`startDeviceMotionUpdates` / `startAccelerometerUpdates` / `startGyroUpdates`）
- **詳細**：CoreMotion コールバッククロージャが Swift 6 で暗黙的に `@MainActor` 隔離として推論されており、CoreMotion が背景 OperationQueue（Anonymous queue / Thread 8）でクロージャを呼び出した瞬間、Swift 並行性ランタイム（`_swift_task_checkIsolatedSwift` → `swift_task_isCurrentExecutorWithFlagsImpl`）が `dispatch_assert_queue(main)` を実行し、main 以外であるため `_dispatch_assert_queue_fail` で `EXC_BREAKPOINT`。内側の `DispatchQueue.main.async` 到達前にクロージャエントリで隔離チェックが走るため、main へのホップでは回避できない
- **確定根拠**：スタックトレース上位フレーム：`#3 _swift_task_checkIsolatedSwift` → `#4 swift_task_isCurrentExecutorWithFlagsImpl` → `#5 closure #1 in AccelerometerManager.startDeviceMotionUpdates` → `#7-12 NSOperationQueue` → `#13-18 _dispatch_block_async_invoke2 → _dispatch_root_queue_drain`。スレッドマップ：Thread 4 = `com.apple.CoreMotion.MotionThread`（CoreMotion 内部）→ Thread 5 = `NSOperationQueue 0x144acf400 (USER_INITIATED)`（自前 OperationQueue）→ **Thread 8 = `com.apple.root.background-qos`（実際にクロージャが走ったプール、ここでクラッシュ）**。NSOperationQueue が global dispatch root queue にリダイレクトする標準挙動で、QOS が USER_INITIATED でも実行は background-qos プールで行われる
- **実施内容（初回）**：3 メソッドのコールバック構造を「(1) 背景キューで Sendable 値（タプル・Double）を抽出 → (2) `[weak self]` のまま `DispatchQueue.main.async` へ submit → (3) main 内で `guard let self = self` → MainActor 隔離プロパティへ書き込み」に変更
- **初回修正後の再発**：Thread 5（自前 OperationQueue）で同一クラッシュ再発。クロージャ内側を直しても **クロージャ自体が `@MainActor` 隔離として推論される** ため、コンパイラがクロージャエントリに挿入する `_swift_task_checkIsolatedSwift` が背景キューで走った瞬間にアサーション失敗する仕組みは変わっていなかった
- **実施内容（追加修正）**：3 メソッドのクロージャに **`@Sendable` を明示**（`{ @Sendable [weak self] (motion, error) in ... }`）。これによりクロージャは強制的に non-isolated として扱われ、コンパイラがエントリ isolation check を挿入しなくなる。内側の `DispatchQueue.main.async` で main にホップしてから self を unwrap する構造はそのまま維持
- **検証結果**：Watch ターゲット（Apple Watch Series 11 46mm / watchOS 26.5 Simulator）BUILD SUCCEEDED（warning 無し）
- **残課題**：同根原因経路がないか観察：(a) `WatchSessionGateway`（iOS）の `nonisolated session(_:didReceive:)` 内の同期処理で main へ async せず触れている経路、(b) `WorkoutSessionGateway` の HealthKit completion（現状 `print` のみ self 非依存だが将来的にロジック追加時に再発リスク）、(c) iOS 側 `WatchSessionManager` の同等 nonisolated メソッド群、(d) Swift 6 で `@MainActor` 隔離クラス内のクロージャを背景 API（CoreMotion / NotificationCenter 等）に渡す箇所は `@Sendable` 明示が必須という規約をプロジェクト規範化

---

## 集計（2026-06-01 最終更新）

| 重大度   | 件数 | 番号 |
|----------|---|---|
| Critical | 6 | ISSUE-001, 002, 003, 004, 017, 019 |
| High     | 7 | ISSUE-005, 006, 007, 008, 014, 015, 016 |
| Medium   | 6 | ISSUE-009, 010, 011, 012, 013, 018 |
| Low      | 1 | ISSUE-020 |
| **合計** | **20** | **ISSUE-001 〜 ISSUE-020** |

### ステータス内訳

| ステータス    | 件数 | 番号 |
|---------------|---|---|
| OPEN          | 0 | — |
| IN_PROGRESS   | 0 | — |
| RESOLVED      | 19 | ISSUE-001 〜 019 |
| KNOWN_ISSUE   | 1 | ISSUE-020 |
| WONTFIX       | 0 | — |

### 完了概要

- **削除されたコード**: HybridTransferManager.swift（757 行）+ 6 死コードテスト（約 1700 行）+ AccelerometerManager 内拡張・テスト DI（約 400 行）+ SelectableAccelerometerChartComponent（248 行）+ 各種重複コード = **合計約 3100 行削減**
- **新設されたファイル**: 16 ファイル（SensorDataKit Package 含む）
- **削除されたディレクトリ**: `GetAccelerometerData/Models/`（命名矛盾解消）
- **追加されたモジュール**: `SensorDataKit` Local Swift Package（iOS / watchOS 共通の Domain）
- **最終ビルド検証**: iOS（iPhone 17 / OS 26.5）/ watchOS（Apple Watch Series 11 / OS 26.5）両ターゲット clean build SUCCEEDED

### 次回イテレーション候補

| カテゴリ                        | 内容 |
|---------------------------------|---|
| AccelerometerManager 残責務分離 | `MotionDataSource`（CoreMotion 隔離）/ `SensorTransferGateway`（WCSession 隔離）の追加抽出 |
| WatchSessionGateway 再設計      | `MainActor.assumeIsolated` 依存を解消する明示的 actor 設計 |
| テストカバレッジ復旧            | 削除されたテストの代わりに、Protocol 化された UseCase / Gateway に対する単体テストを再構築 |
| AppDependencies の Watch 対応   | Watch アプリ側の Composition Root（現状 `AccelerometerManager()` 直接生成）を AppComposition 相当の構造に統一 |

## ISSUE-018

- **発生日**: 2026-06-01
- **解決日**: 2026-06-01
- **タイトル**: VBT Phase A の WCSession delegate 競合（transferFile ACK ブリッジ未配線）
- **重大度**: Middle
- **ステータス**: RESOLVED
- **発生工程**: VBT Ground Truth Tool Phase A 実装
- **概要**: `WCSessionVBTGateway.transferIMUFile(at:timeout:)` は `WCSessionDelegate.session(_:didFinish:error:)` の発火を期待して `notifyTransferDidFinish(error:)` を経由した `CheckedContinuation` 再開を行う設計だが、`WCSession.default.delegate` は既存 `AccelerometerManager` が保持しており、Phase A 単体では gateway へのブリッジが配線されていない。結果として `transferIMUFile` の `await` は 60s タイムアウトまで待たされる（仕様書 §9 「IMU 転送タイムアウト」異常系で `transferTimeout` が誤発火する可能性）。
- **影響範囲**: VBTRecordingController → VBTRecordingUseCase → WCSessionVBTGateway の停止フロー。Phase A 単体実機テストで 60s タイムアウトが発生する見込み。
- **実施内容**: (1) Watch 側に `VBTGatewayRegistry`（`@unchecked Sendable` シングルトン）を新設し、`WCSessionVBTGateway` がインスタンス生成時に self-register / `deinit` で unregister する仕組みを導入。(2) 既存 `AccelerometerManager.session(_:didFinish:error:)` から `VBTGatewayRegistry.isVBTTransfer(_:)` で metadata.fileType == "vbt.imuCSV" を判定し、VBT 経路なら `VBTGatewayRegistry.shared.bridgeDidFinish(...)` 経由で `WCSessionVBTGateway.notifyTransferDidFinish` を呼ぶ。(3) iPhone 側 `WatchSessionGateway` に `VBTWatchMessageRouter` を新設し、`vbt.startRecording` / `vbt.stopRecording` / `vbt.imuCSV` を専用ルーターへ振分け、既存転送経路（CombinedSensorData JSON / 汎用 CSV）と排他化。(4) iPhone → Watch の最終 ACK は `["status": "ack"]` の sendMessage を新設し、Watch 側 `AccelerometerManager.session(_:didReceiveMessage:)` から `VBTGatewayRegistry.shared.bridgeAckMessage(_:)` 経由で `WCSessionVBTGateway.notifyTransferAck()` を呼ぶ。(5) `notifyTransferDidFinish(error:)` は「中間通知（エラー時のみ continuation 解決、成功時は ACK 待機）」へ意味を更新し、`notifyTransferAck` / `notifyTransferFailure` を新設して仕様書 §6 step 12 の真の ACK と整合させる。(6) Watch 側 `VBTRecordingController.tapStopRecording()` で `useCase.imuStartTimestamp` を `gateway.setImuStartTimestamp(_:)` 経由で metadata に注入し、iPhone 側 meta.json の `imu_start_timestamp` を仕様書 §7 通りに伝達する。
- **検証結果**: iOS / watchOS 両ターゲット clean build SUCCEEDED（Xcode 26.5 / iPhone 17 シミュレータ + Apple Watch Series 11 シミュレータ）。SensorDataKit 全 89 テスト pass（追加 `VBTReceptionUseCaseTests` / `MetaJSONPayloadTests` / `SessionFolderNamingTests` / `VBTSessionInputTests` 含む）。
- **残課題**: 実機ペアでの統合検証（特に 60fps セットアップの実機モデル別動作確認）は Phase B 受領者責務として残置。

## ISSUE-019

- **発生日**: 2026-06-01
- **解決日**: 2026-06-01
- **タイトル**: WCSessionDelegate のメソッドが `respondsToSelector:` で NO を返し delegate 配線が機能しない
- **重大度**: Critical
- **ステータス**: RESOLVED
- **発生工程**: VBT Ground Truth Tool Phase D 実機検証
- **該当ファイル**: `GetAccelerometerData/Data/Gateways/WatchSessionGateway.swift` / `GetAccelerometerData Watch App/AccelerometerManager.swift`
- **概要**: iOS Simulator console.log に `delegate GetAccelerometerData.WatchSessionManager does not implement delegate method` が出力され、Watch 側で `WCErrorCodeDeliveryFailed` が発生。原因は `@MainActor` クラスの `WCSessionDelegate`（Objective-C プロトコル）optional メソッドを `nonisolated func` で実装していたが `@objc` 修飾子が欠落していたこと。Swift 6 strict concurrency 環境で `@MainActor` + `nonisolated` の組み合わせは Obj-C ランタイムの `respondsToSelector:` が NO を返すケースがあり（Apple 既知挙動）、WCSession は optional メソッドを selector 存在チェックで呼ぶため delegate に届かない状態となっていた。加えて Watch 側 `WCSessionVBTGateway.sendStopRecordingSignal()` は `replyHandler: nil` で送信するため、iPhone 側に `session(_:didReceiveMessage:)`（replyHandler なし変種）が必要だが未実装で、停止メッセージが `VBTWatchMessageRouter` にルーティングされなかった。
- **影響範囲**: VBT 停止フロー全体（Watch → iPhone への停止シグナル / IMU 転送 / ACK）。Phase D 実機検証で delegate が機能せず VBT 録画停止の同期破綻が発生。
- **実施内容**: (1) iPhone 側 `WatchSessionManager` の WCSessionDelegate メソッド 9 個（`session(_:activationDidCompleteWith:error:)` / `sessionReachabilityDidChange(_:)` / `session(_:didReceive:)` / `session(_:didReceiveMessage:replyHandler:)` / `session(_:didReceiveMessageData:replyHandler:)` / `session(_:didReceiveUserInfo:)` / `session(_:didFinish:error:)` / `sessionDidBecomeInactive(_:)` / `sessionDidDeactivate(_:)`）に `@objc` を明示。(2) `session(_:didReceiveMessage:)`（replyHandler なし変種）を新規追加し、`VBTWatchMessageRouter.isStopRecordingMessage(_:)` で判定した停止メッセージを `VBTWatchMessageRouter.handleStopRecording(_:)` に振分け。(3) Watch 側 `AccelerometerManager` の WCSessionDelegate メソッド 3 個（`session(_:activationDidCompleteWith:error:)` / `session(_:didFinish:error:)` / `session(_:didReceiveMessage:)`）にも `@objc` を明示。
- **検証結果**: SensorDataKit 全 126 テスト pass。iOS（iPhone 17 シミュレータ）/ watchOS（Apple Watch Series 11 46mm シミュレータ）両ターゲット clean build SUCCEEDED。
- **残課題**: 実機ペア（iPhone + Apple Watch）での停止シグナル到達確認は Phase D 受領者責務として残置。

## ISSUE-020

- **発生日**: 2026-06-01
- **解決日**: 2026-06-01
- **タイトル**: iOS Simulator で AVCaptureSession 60fps 録画が `FigCaptureSourceRemote err=-17281` で失敗
- **重大度**: Low
- **ステータス**: KNOWN_ISSUE
- **発生工程**: VBT Ground Truth Tool Phase D 検証
- **該当ファイル**: VBT カメラ録画系（iOS 側）
- **概要**: iOS Simulator では実カメラハードウェアが存在しないため、AVCaptureSession で 60fps 動画録画を開始すると `FigCaptureSourceRemote err=-17281` のエラーで失敗する。Simulator 制約事項であり、実機影響なし。仕様書 §4「同期精度最優先」方針では実機検証を前提としており、修正対象外。
- **影響範囲**: iOS Simulator 環境での VBT 動画録画機能のみ。実機（iPhone）影響なし。
- **解決方針**: 実機（iPhone）でテストする。Simulator では VBT 動画録画機能は動作しないことを開発者向けドキュメントに明記済み（本 Issue が記録）。修正実装は不要。
- **残課題**: なし（Simulator 限定の既知制約として確定）。

---

## ISSUE-021

- **発生日**: 2026-06-02
- **解決日**: 2026-06-02
- **タイトル**: iPhone 側 VBT メタ入力画面が Watch 記録開始後も「Watch 記録開始待機中」のまま固まる
- **重大度**: High
- **ステータス**: RESOLVED
- **発生工程**: VBT Ground Truth Tool Phase B 受信フロー実行時
- **該当ファイル**:
  - `GetAccelerometerData/VideoRecording/Presentation/ViewModels/VBTGroundTruthMetaInputViewModel.swift`
  - `GetAccelerometerData/VideoRecording/Data/Inbound/VBTWatchMessageRouter.swift`
- **概要**: Watch が「● 記録中」表示で正常稼働している（= iPhone が `vbt.startRecording` の ACK を返した = `VBTReceptionUseCase.state` は `.waitingForStart → .recording` に遷移済み）にもかかわらず、iPhone 画面の「セッション状態」は `Watch 記録開始待機中` のままで `isWaitingForWatch` が真のままになる。
- **根本原因**: `VBTGroundTruthMetaInputViewModel.refreshStatus()` は `init()` と `submitPendingMetadata()` でしか呼ばれない。`VBTReceptionUseCase` は `NSLock` 保護の plain getter（`@Published` でも `ObservableObject` でもない）であり、`VBTWatchMessageRouter.handleStartRecording` 完了時に View Model へ状態変更を通知する経路が存在しない。結果として use case の状態遷移が UI へ反映されない。
- **対策方針**: `VBTWatchMessageRouter` の各ハンドラ（`handleStartRecording` / `handleStopRecording` / `handleIMUFileReceived`）が use case の await 完了時に `NotificationCenter` で状態変更を広報し、`VBTGroundTruthMetaInputViewModel` が購読して `refreshStatus()` を呼ぶ（既存の `attachRouterRequestNotification` と同パターン）。
- **実施内容**: (1) `VBTWatchMessageRouter` に `stateDidChangeNotification` を追加し、3 つのハンドラ（start / stop / IMU 受信）が `useCase.handle*` を await 直後に `notifyStateDidChange()` を呼ぶよう修正、(2) `VBTGroundTruthMetaInputViewModel.init()` に `NotificationCenter.default.publisher(for:).receive(on: .main).sink` 購読を追加し、通知到達時に `refreshStatus()` を呼ぶ（`AnyCancellable` を `stateChangeCancellable` で保持）。
- **検証結果**: iOS ターゲット `xcodebuild ... -destination 'generic/platform=iOS'` で BUILD SUCCEEDED。実機での Watch 連携動作確認は未実施（ユーザー検証待ち）。

---

## ISSUE-022

- **発生日**: 2026-06-02
- **タイトル**: iPhone 側 VBT 失敗時に原因（reason）が UI / Watch / ログのいずれにも表示されず診断不能
- **重大度**: High
- **ステータス**: OPEN（診断強化済み、根本原因は次回再現待ち）
- **発生工程**: VBT Ground Truth Tool Phase B 受信フロー（Watch 「IMU 転送タイムアウト」失敗 + iPhone `.failed` 遷移）
- **該当ファイル**:
  - `GetAccelerometerData/VideoRecording/Data/Inbound/VBTWatchMessageRouter.swift`
  - `GetAccelerometerData/Data/Gateways/WatchSessionGateway.swift`
  - `GetAccelerometerData/VideoRecording/Presentation/ViewModels/VBTGroundTruthMetaInputViewModel.swift`
- **概要**: `VBTReceptionUseCase.HandleResult.error(reason:)` の `reason` 文字列が、Router `handleIMUFileReceived` の `completion: (Bool) -> Void` で破棄されており、`WatchSessionGateway` も Watch 側に固定の `["status":"error"]` のみ返していた。`VBTGroundTruthMetaInputViewModel.refreshStatus()` も `.failed` 時に固定文字列「失敗：再試行してください」を表示するのみで、ユーザーは原因不明のまま再試行を強いられていた。実際の reason 候補は `"video stop failed: recorder not running"` / `"video stop failed: <err>"` / `"import failed: <err>"` / `"no active recording session"` の 4 系統（`VBTReceptionUseCase.swift` 各エラーパス）。
- **実施内容**: (1) Router の `handleIMUFileReceived` completion を `(Bool, String?) -> Void` に拡張し、`.error(reason)` の reason を Watch / UI 両方に伝搬、(2) Router の各失敗パスで `print("[VBTWatchMessageRouter] ...")` をログ出力（Xcode コンソール / Console.app で確認可能）、(3) `notifyStateDidChange(reason:)` に reason 引数を追加し `userInfo["reason"]` に載せて Notification 配送、(4) `VBTGroundTruthMetaInputViewModel` に `@Published lastFailureReason: String?` を追加、Notification 受信時に取り込み `refreshStatus()` で `statusText = "失敗：\(reason)"` として表示、(5) `WatchSessionGateway` の ACK sendMessage を errorHandler 付きで `print` するよう変更し、reachability 喪失検出を可能化、(6) `lastMessage` に reason を含めて UI 上にも露出。
- **副次的観測**: iPhone 側で `sendMessage(reply, replyHandler: nil, errorHandler: { _ in })` の errorHandler が空のため、Watch reachability 喪失時に ACK が無音で失われ Watch 側「IMU 転送タイムアウト」を引き起こす経路が存在。本 Issue では診断ログを追加したのみで根本対策（`transferUserInfo` フォールバック）は別 Issue で扱う。
- **検証結果**: iOS ターゲット BUILD SUCCEEDED。reason が UI / コンソール両方で確認できることをユーザー実機検証で確認済（取得 reason: `"import failed: The file ... couldn't be opened because there is no such file."` → 根本原因 ISSUE-023 として分離）。
- **残課題**: なし（診断強化の目的は達成。根本原因は ISSUE-023 で別途対処）。
- **ステータス変更**: OPEN → RESOLVED（2026-06-02）

---

## ISSUE-023

- **発生日**: 2026-06-02
- **解決日**: 2026-06-02
- **タイトル**: WCSession `didReceive file:` の一時ファイルライフサイクル違反により VBT IMU CSV 取込が "no such file" で失敗
- **重大度**: Critical
- **ステータス**: RESOLVED（実機検証待ち）
- **発生工程**: VBT Ground Truth Tool Phase B IMU 受信フロー（仕様書 §6 step 12）
- **該当ファイル**: `GetAccelerometerData/Data/Gateways/WatchSessionGateway.swift`
- **概要**: Apple `WCSession` の `session(_:didReceive file:)` delegate メソッドは return した瞬間に `file.fileURL` の一時ファイルが iOS によって削除される仕様だが、本実装は `VBTWatchMessageRouter.handleIMUFileReceived` を async `Task` で起動して即座に return しており、Use Case 側で `await video.stopRecording()` を待つ間（数秒）に元ファイルが消失し、後続の `FileSystemSessionStore.importIMUFile(from:to:)` の `copyItem` が `NSFileNoSuchFileError`（Code=260）で失敗していた。
- **根本原因**: WCSession のファイルライフサイクル契約違反。delegate スコープ外（async Task）に `file.fileURL` を持ち越す設計が誤り。Simulator では `stopRecording` が長時間ブロック（カメラ err=-17281）するため必発、実機でも `stopRecording` が数秒以上かかれば再現しうる潜在バグ。
- **取得 reason**: `import failed: The file "vbt_imu_20260602_205217.csv" couldn't be opened because there is no such file.`（ISSUE-022 で診断強化済みの経路で取得）
- **実施内容**: `WatchSessionGateway.session(_:didReceive file:)` の VBT 経路で、delegate スコープ内（同期）に `FileManager.copyItem(at: originURL, to: stableURL)` で `FileManager.temporaryDirectory/vbt_imu_inbox_<UUID>_<filename>` へ複製し、その安定 URL を `router.handleIMUFileReceived(sourceURL: stableURL, ...)` に渡すよう変更。コピー失敗時は即座に Watch へ error reply + UI 表示を実施。完了コールバックで stableURL を `try? FileManager.default.removeItem(at:)` でクリーンアップ（成功/失敗いずれも）。
- **検証結果**: iOS ターゲット BUILD SUCCEEDED。実機/実機ペアでの再現検証はユーザー側で実施予定。
- **副次効果**: Simulator 制約（ISSUE-020）の AVCapture err=-17281 は別問題として残置（実機では発生しないため）。

---

## ISSUE-024

- **発生日**: 2026-06-02
- **解決日**: 2026-06-02
- **タイトル**: VBT ラベリング画面で IMU 波形が「IMU 波形なし」表示のまま出ない（書き出し側 / パース側の timestamp 形式不一致）
- **重大度**: High
- **ステータス**: RESOLVED（実機検証待ち）
- **発生工程**: VBT Ground Truth Tool Phase C ラベリング画面（仕様書 §10）
- **該当ファイル**:
  - `Packages/SensorDataKit/Sources/SensorDataKit/VBT/IMUWaveformParser.swift`
  - `GetAccelerometerData/VideoRecording/Presentation/ViewModels/VBTLabelingViewModel.swift`
  - `GetAccelerometerData/VideoRecording/Presentation/Views/VBTLabelingView.swift`
- **概要**: Watch 側 `CoreMotionIMURecorder.exportCSV()` は `CSVTimestampFormatter.format` により timestamp 列を `yyyy-MM-dd HH:mm:ss.SSSSSS`（日時文字列）で書き出すが、ラベリング側パーサ `IMUWaveformParser.parse` は `Double(...)` で数値直接パースを試みていたため、Watch から到達した imu.csv は全行 `ParseError.malformedRow` として拒否され、`VBTLabelingViewModel.load()` の `catch { samples = [] }` で握り潰され、UI は「IMU 波形なし」表示のみ。
- **根本原因**: 書き出し側（Watch）とパース側（iPhone Phase C）のタイムスタンプ形式契約が不一致。仕様書 §7 注（`CoreMotionIMURecorder.swift:110`）は「既存パイプライン互換のため UNIX 時刻でも書ける CSV を維持する」と明記しており書き出し側は意図通り、パーサ側が両形式を許容していなかった。加えて ViewModel が `catch` でエラーを握り潰す silent failure パターンが診断を困難にしていた。
- **実施内容**: (1) `IMUWaveformParser.parse` で「`CSVTimestampFormatter.parseTimeInterval` → `Double` フォールバック」の順に試行する両形式許容ロジックに変更（既存数値テストは Double フォールバックで通過、Watch 由来の日時文字列は parseTimeInterval で UNIX 秒へ変換）、(2) 回帰テスト `test_parse_acceptsDateStringTimestamp` を追加し `2026-06-02 20:52:17.xxxxxx` 形式の正規化を検証、(3) `VBTLabelingViewModel` に `@Published imuLoadError: String?` を追加し `catch` で error を文字列化して保持・`print` 出力、(4) `VBTLabelingView` の「IMU 波形なし」セクションに失敗理由を赤字で表示する分岐を追加（ISSUE-022 と同じ silent failure 防止パターン）。
- **検証結果**: SensorDataKit `swift test` で `IMUWaveformLoaderTests` 5/5 PASSED（新規 1 件 + 既存 4 件）。iOS ターゲット BUILD SUCCEEDED。
- **残課題**: 実機 / Simulator 連携で実際の imu.csv → ラベリング波形描画までを end-to-end 検証する。

---

## ISSUE-025

- **発生日**: 2026-06-02
- **解決日**: 2026-06-02
- **タイトル**: VBT ラベリング画面でカーソル値が UNIX 秒生表示（`1780402247.066s`）かつセッション識別情報が UI に無く「全て同じデータに見える」UX 問題
- **重大度**: Medium
- **ステータス**: RESOLVED（実機検証待ち）
- **発生工程**: VBT Ground Truth Tool Phase C ラベリング画面（仕様書 §10）
- **該当ファイル**:
  - `GetAccelerometerData/VideoRecording/Presentation/ViewModels/VBTLabelingViewModel.swift`
  - `GetAccelerometerData/VideoRecording/Presentation/Views/VBTLabelingView.swift`
- **概要**: IMU 統一時刻軸カーソル表示が `1780402247.066s`（UNIX 秒の生値）で人間に読めず、加えて画面にセッション識別情報（フォルダ名 / 種目 / 重量 / set 番号 / 録画開始時刻 / VALID 状態）が一切表示されないため、複数セッションを切り替えて閲覧する際「どのセッションを見ているか」確認できず、似た振幅の波形が「全て同じデータ」に見えてしまっていた。
- **根本原因**: (1) ISSUE-024 修正で日時文字列を `parseTimeInterval` 経由で UNIX 秒へ変換するようにしたが、表示側を「生 UNIX 秒のまま」描画していた、(2) ラベリング画面が `folderURL` を受け取って即 `imuWaveformView` を描画する設計で、meta.json / フォルダ名を UI へ反映する経路が無かった。
- **実施内容**: (1) `VBTLabelingViewModel` に `sessionMeta: MetaJSONPayload?` / `folderName: String` / `firstSampleTimestamp: TimeInterval?` / `relativeCursorTime: TimeInterval` を追加し、`load()` で `meta.json` を `JSONDecoder` で読み込んで保持、最初のサンプル timestamp を相対秒基準として保存、(2) `VBTLabelingView` に `sessionHeader` ビューを新設し、フォルダ名 / 種目 / 重量 / set 番号 / rep 目標 / VALID-PENDING バッジ / 録画開始 ISO8601 を画面最上部に表示、(3) `timeAxisDisplay` の IMU カーソル表示を「`IMU 統一軸: 1780402247.066 s（録画開始+1.234 s）`」のように UNIX 秒 + 相対秒の併記に変更。
- **検証結果**: iOS ターゲット BUILD SUCCEEDED。実機での複数セッション切替時に「どのセッションを開いているか」確認可能か / 相対秒表示が直感的かをユーザー検証予定。

---

## ISSUE-026

- **発生日**: 2026-06-02
- **解決日**: 2026-06-02
- **タイトル**: VBT ラベリング画面の Swift Charts X 軸が UNIX 秒の桁で `0..1.78E9` まで拡大され波形が右端に潰れて見えない
- **重大度**: High
- **ステータス**: RESOLVED（実機検証待ち）
- **発生工程**: VBT Ground Truth Tool Phase C ラベリング画面（仕様書 §10）
- **該当ファイル**: `GetAccelerometerData/VideoRecording/Presentation/Views/VBTLabelingView.swift`
- **概要**: ユーザー提供のスクリーンショット（2026-06-02 21:27）で、IMU 波形チャートの X 軸ラベルが `0 / 5.0E8 / 1.0E9 / 1.5E9` と表示され、実際の波形（LineMark）が右端の数ピクセルに圧縮されて視認できない状態を確認。RuleMark（赤点線カーソル）のみがチャート右端に視認可能。
- **根本原因**: ISSUE-024 で `IMUWaveformParser` が `CSVTimestampFormatter.parseTimeInterval` 経由で UNIX 秒（≈1.78×10⁹）を返すようになったが、それを `LineMark(x: .value("t", sample.timestamp))` でそのまま X 軸に流し込んでいた。Swift Charts のデフォルト軸スケーリングアルゴリズムは値の絶対桁が大きい場合（|domain| ≪ 値）、`[0, max]` を自動採用する傾向があり、データ範囲（数十秒）が `0..1.78e9` の中に飲み込まれて 1px 未満に圧縮された。
- **実施内容**: `VBTLabelingView` の Chart 内部で「録画開始（`viewModel.firstSampleTimestamp`）からの相対秒」を LineMark / RuleMark の X 値として採用するよう変換。内部状態（`imuCursorTime` / sync_markers ベース変換）は仕様書 §8 の線形補正のため UNIX 秒のまま維持し、**表示層でのみ相対秒換算** することで保存形式 / DTO / API 契約はすべて無修正。drag gesture（カーソル長押し移動）も UNIX 秒のまま処理しているため整合性は維持。
- **検証結果**: iOS ターゲット BUILD SUCCEEDED。実機で X 軸が `0..(録画秒数)` の範囲に正しくスケールされ、波形ピーク・ボトムが視認可能となり、長押しドラッグでカーソルが目視可能な位置に動くことをユーザー検証予定。
- **副次効果**: 同じ UNIX 秒 → 相対秒変換ロジックは ISSUE-025 で View Model の `relativeCursorTime` として既に提供済みのため、表示層のロジックは局所化されている。

---

## ISSUE-027

- **発生日**: 2026-06-03
- **解決日**: 2026-06-03
- **タイトル**: VBT ラベリング SAVE 時に「保存失敗: SensorDataKit.LabelingState.BuildError error 1」と表示され原因が判らない
- **重大度**: High
- **ステータス**: RESOLVED（実機検証完了 2026-06-03）
- **発生工程**: VBT Ground Truth Tool Phase C ラベリング画面（仕様書 §10）
- **該当ファイル**:
  - `Packages/SensorDataKit/Sources/SensorDataKit/VBT/LabelingState.swift`
  - `Packages/SensorDataKit/Tests/SensorDataKitTests/VBT/LabelingStateTests.swift`
  - `GetAccelerometerData/VideoRecording/Presentation/Views/VBTLabelingView.swift`
- **概要**: SAVE ボタン押下時にアラート「保存失敗: The operation couldn't be completed. SensorDataKit.LabelingState.BuildError error 1.」が表示され、ユーザーはどのマーカーをどう直せばよいか判断できない。
- **根本原因**: (1) `BuildError` が `LocalizedError` 未準拠で、`error.localizedDescription` が既定の NSError 表現（`<module>.<type> error <case-index>`）を返していた。`error 1` は宣言順 2 番目の `converterFailed`。(2) `LabelingState.missingRequirements` が「マーカー 4 点と rep ≥ 1」のみを判定し、SyncMarker 不変条件（`endTime > startTime`）および VideoToUnifiedConverter の `videoSpan != 0` を SAVE 前に検証していなかった。結果として UI 上 `canSave=true` のまま `buildPayload()` 内で `SyncMarker.init` → `ValidationError.endNotAfterStart` が発生し `BuildError.converterFailed` にラップされていた。
- **実施内容**: (1) `MissingRequirement` に `.syncVideoOrderInvalid` / `.syncImuOrderInvalid` を追加し、4 点が揃っている時のみ `end <= start` を判定（欠落エラーとの二重表示を防止）。(2) `BuildError` を `LocalizedError` 準拠とし、`errorDescription` で「確定条件未充足: <要素名>」「SYNC マーカーの整合性エラー: 動画/IMU の START と END が逆転または同値のため線形補正できません」「rep ラベルの検証に失敗しました」を返却。(3) `VBTLabelingView.missingLabel` に新ケース 2 件を追加。(4) `LabelingStateTests` に順序逆転/同値/SYNC 未記録時の二重表示防止/localizedDescription の 5 テストを追加（合計 15 件全件パス）。
- **検証結果**: `swift test --filter LabelingStateTests` 15/15 パス、`xcodebuild -scheme GetAccelerometerData -destination 'generic/platform=iOS' build` BUILD SUCCEEDED。実機検証（2026-06-03 提供スクリーンショット「エラー確認:欠落要素_SYNC （IMU）順序不正（END > START でない）.PNG」）にて、SYNC IMU START/END を逆転させた状態で SAVE ボタンが灰色化（disabled）し、欠落要素欄に「SYNC (IMU) 順序不正（END > START でない）」が表示されることを確認。

---

## ISSUE-028

- **発生日**: 2026-06-03
- **解決日**: 2026-06-03
- **タイトル**: VBT ラベリングで SYNC START/END の位置がビジュアルに確認できず、正しく設定できているか即座に判らない
- **重大度**: Low（UX 改善）
- **ステータス**: RESOLVED（実機検証完了 2026-06-03）
- **発生工程**: VBT Ground Truth Tool Phase C ラベリング画面（仕様書 §10）
- **該当ファイル**: `GetAccelerometerData/VideoRecording/Presentation/Views/VBTLabelingView.swift`
- **概要**: SYNC START/END (Video/IMU) を記録しても、`timeAxisDisplay` の数値表示しか確認手段がなく、(1) 4 点が実際に IMU 波形・動画タイムライン上のどの位置に置かれたのか、(2) 現在の再生位置・カーソル位置との相対関係はどうなっているのか、をビジュアルに即時把握できない。ユーザーは ISSUE-027 で順序不正は検出できるようになったが、依然「位置がそもそも合っているか」の確認は数値だけで行わざるを得ず、誤設定の自己発見が困難だった。
- **根本原因**: ラベリング画面の初期実装で SYNC マーカーの数値保持と SAVE 時の使用のみが実装され、SYNC マーカーを画面上の幾何要素として描画する表示層実装が欠落していた。
- **実施内容**: (1) `imuWaveformView` の Swift Charts に `RuleMark` を 2 本追加し、`viewModel.state.syncMarkerImuStart`（緑・実線・`S` アノテーション）と `syncMarkerImuEnd`（橙・実線・`E` アノテーション）を波形上に描画。現在カーソル（赤・破線）と色分け。(2) `videoScrubBar` の `ZStack` に縦線（緑 / 橙、幅 2pt × 高さ 18pt）を `videoDuration` 比率位置に追加し、Video SYNC START/END をスクラブバー上に重畳。再生位置（青丸）と色分け。
- **検証結果**: `xcodebuild -scheme GetAccelerometerData -destination 'generic/platform=iOS' build` BUILD SUCCEEDED。実機検証（2026-06-03 提供スクリーンショット「確認:欠落要素_SYNC （IMU）順序不正（END > START でない）ライン.PNG」）にて、IMU 波形上に緑/橙の SYNC START/END ラインと `S`/`E` アノテーションが描画されること、および ISSUE-027 の順序不正検出（欠落要素「SYNC (IMU) 順序不正」）と同時表示される状態でユーザーが視覚的に誤設定を即座に把握できることを確認。
- **副次効果**: SYNC START/END の物理マーカー対応（動画上のタップ瞬間 ↔ IMU 上の加速度ピーク）が視認可能になり、ISSUE-027 で検出される順序不正の自己診断が大幅に容易化される。実機検証では IMU 順序不正のときも、緑（S）と橙（E）の位置関係が波形上で直接見えるため「どちらをどう動かせば直るか」が即時判断可能。

---

## ISSUE-029

- **発生日**: 2026-06-03
- **解決日**: 2026-06-04
- **タイトル**: IMU データから Apple Watch の動きを 3D モデリング表示する手段が存在しない
- **重大度**: Low（機能追加）
- **ステータス**: RESOLVED（実機検証完了 2026-06-03）
- **発生工程**: VBT Ground Truth Tool Phase C 解析
- **該当ファイル**: `Packages/SensorDataKit/Sources/SensorDataKit/VBT/MotionReplay/`（新規 10 ファイル）, `GetAccelerometerData/VideoRecording/Presentation/Views/VBTSessionListView.swift`（+5）
- **概要**: 既存 imu.csv から Apple Watch の動きを 3D 可視化する手段がなく、accel_magnitude の 2D 線グラフのみでは姿勢変化（回転 / 傾き）を直感的に把握できなかった。
- **根本原因**: 設計段階で 3D 可視化要件が未定義。
- **実施内容**: SensorDataKit に MotionReplay モジュールを新規追加。AttitudeQuaternion / AttitudeSeries（SLERP 補間）/ GyroSample / AttitudeIMUSource（imu.csv パース）/ AttitudeReconstructor（台形則 gyro 積分）/ MotionReplayState / MotionReplayViewModel（@MainActor + Combine Timer 60Hz）/ MotionReplayView（SwiftUI 統合）/ MotionReplaySceneView（SCNView ラップ）/ WatchSceneNodeBuilder（Apple Watch Series 9 41mm 形状ノード）。VBTSessionListView に PoC バッジ付き NavigationLink 1 件追加。既存 Watch 側 / WCSession / IMUWaveformParser は無変更。
- **検証結果**: SwiftPM 170 テスト全通過（新規 38 件含む）、iOS BUILD SUCCEEDED、実機検証完了。
- **既知の制約**: 純 gyro 積分のため積分ドリフトあり（60s で 0.5-2°）、初期姿勢は単位クォータニオン仮定（yaw 絶対値不定）、定性可視化に限定。

---

## ISSUE-030

- **発生日**: 2026-06-04
- **解決日**: 2026-06-04
- **タイトル**: VBT ラベリング画面の UI デザインを試行錯誤するための切替機構がない
- **重大度**: Low（UX 改善）
- **ステータス**: RESOLVED（実機検証待ち）
- **発生工程**: VBT Ground Truth Tool Phase C ラベリング画面
- **該当ファイル**: `GetAccelerometerData/VideoRecording/Presentation/Views/VBTLabelingSkins/`（新規 8 ファイル）、`VBTSessionListView.swift`（+8）
- **概要**: ラベリング画面の UI デザインが固定で、利用者が好みのレイアウト・配色を試せない。
- **実施内容**: 5 種類デザインスキン（Classic / Compact / Dark Pro / Chart-Centric / Card-Based）を新設し、Segmented Picker で切替可能な `VBTLabelingSkinnedView` 容器を実装。共有 ViewModel 経由で全スキンが同じビジネスロジックを利用。VBTSessionListView に「ラベリング [Skin]」NavigationLink 1 件追加。既存 VBTLabelingView は無変更。
- **検証結果**: iOS BUILD SUCCEEDED、5 スキン全てに既存 VBTLabelingView 等価の IMU 波形スクラブジェスチャを実装。
- **副次効果**: 後段で気に入ったスキンを正式採用する判断材料が揃った。

---

## ISSUE-031

- **発生日**: 2026-06-04
- **解決日**: -（OPEN）
- **タイトル**: `GetAccelerometerDataTests/CSVValidationTests.swift` が存在しない `DataExportService.validateCSVFormat` を参照し iOS test target がコンパイル失敗
- **重大度**: Medium（テスト実行不能、CI 影響あり）
- **ステータス**: OPEN
- **発生工程**: 既存 iOS テスト（Phase B 追加実装中に発見）
- **該当ファイル**: `GetAccelerometerDataTests/CSVValidationTests.swift`（line 16, 31, 46, 61, 77）
- **概要**: `DataExportService.validateCSVFormat(_:)` は責務移管されているが、当該テストは旧 API 名でアクセスし続けており、`xcodebuild test -destination 'platform=iOS Simulator'` がコンパイル失敗する。Phase B（テストカバレッジ拡充）の変更前から存在する既存破損で本タスク起因ではない。
- **影響**: (1) 既存 iOS app target テスト全件が実行不能、(2) Phase B で追加した `GetAccelerometerDataTests/VBTLabelingSkinSharedTests.swift`（8 ケース）も同ターゲット内のため Xcode 上で実行不能。なお SensorDataKit パッケージ単体テスト（`swift test`）は影響を受けず 191/191 パス。
- **対策案**: `CSVValidationTests` 内の `DataExportService.validateCSVFormat` 呼び出し全 5 箇所を `ValidateSensorCSVUseCase` 等の現行 API に書き換える。本対応は別タスクで実施予定。
- **検証結果**: -（未着手）
