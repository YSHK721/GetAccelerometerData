import Foundation

// MARK: - SessionFolderNaming
// VBT Ground Truth Tool Phase B: セッションフォルダ命名規則（仕様書 §7）。
//   session_YYYYMMDD_HHMMSS_<exercise>_<weight_kg>kg_set<set_index>
//
// SRP: 命名規則のみを純粋関数で提供。FileManager 操作は本型の責務外。
public enum SessionFolderNaming {

    public static func makeFolderName(
        startedAt: Date,
        exercise: String,
        weightKg: Double,
        setIndex: Int,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: startedAt)

        let weightString: String
        if weightKg == weightKg.rounded() {
            weightString = String(Int(weightKg))
        } else {
            weightString = String(weightKg)
        }
        return "session_\(stamp)_\(exercise)_\(weightString)kg_set\(setIndex)"
    }
}
