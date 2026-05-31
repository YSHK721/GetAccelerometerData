import Foundation
import HealthKit

// MARK: - WorkoutSessionGateway
// HealthKit（HKHealthStore / HKWorkoutSession / HKLiveWorkoutBuilder）を隔離し、
// バックグラウンド実行に必要なワークアウトセッションの開始・終了のみを公開する Gateway。
// AccelerometerManager の責務から HealthKit 関連 6 〜 80 行のロジックを切り出す（ISSUE-001 対応）。
@MainActor
final class WorkoutSessionGateway {

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    /// 現在のセッション状態。`未開始` / `実行中` / `終了` / `エラー: ...` のいずれか。
    private(set) var sessionState: String = "未開始"

    /// 状態変化を AccelerometerManager 等の上位層に通知するためのコールバック。
    private let onStateChange: @MainActor (String) -> Void

    init(onStateChange: @escaping @MainActor (String) -> Void = { _ in }) {
        self.onStateChange = onStateChange
    }

    // MARK: - 認証

    /// HealthKit 認証を要求する。本クラスの利用前に必ず呼び出す。
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKitは利用できません")
            return
        }

        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if let error = error {
                print("HealthKit認証エラー: \(error.localizedDescription)")
            } else if success {
                print("HealthKit認証成功")
            } else {
                print("HealthKit認証拒否")
            }
        }
    }

    // MARK: - セッション制御

    /// ワークアウトセッションを開始する。既存セッションがある場合は終了してから新規セッションを開始。
    func startSession() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKitは利用できません")
            return
        }

        // 既存のワークアウトを終了
        if let session = workoutSession, session.state == .running {
            endSession()
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { (success, error) in
                if let error = error {
                    print("ワークアウトデータ収集開始エラー: \(error.localizedDescription)")
                }
            }

            self.workoutSession = session
            self.workoutBuilder = builder
            updateState("実行中")

            print("ワークアウトセッション開始: \(Date())")
        } catch {
            print("ワークアウトセッション作成エラー: \(error.localizedDescription)")
            updateState("エラー: \(error.localizedDescription)")
        }
    }

    /// ワークアウトセッションを終了する。非同期 finish 完了時に状態を `終了` に更新。
    func endSession() {
        guard let session = workoutSession, let builder = workoutBuilder else {
            return
        }

        session.end()
        builder.endCollection(withEnd: Date()) { (success, error) in
            if let error = error {
                print("ワークアウトデータ収集終了エラー: \(error.localizedDescription)")
            }

            builder.finishWorkout { (workout, error) in
                if let error = error {
                    print("ワークアウト終了エラー: \(error.localizedDescription)")
                } else if let workout = workout {
                    print("ワークアウト保存成功: \(workout)")
                }

                Task { @MainActor in
                    self.updateState("終了")
                }
            }
        }

        self.workoutSession = nil
        self.workoutBuilder = nil
        print("ワークアウトセッション終了: \(Date())")
    }

    // MARK: - Private

    private func updateState(_ newState: String) {
        sessionState = newState
        onStateChange(newState)
    }
}
