import SwiftUI
import UIKit

// MARK: - VBTShareSheetView
// VBT Ground Truth Tool Phase D: iOS 共有シート（UIActivityViewController）の SwiftUI ブリッジ。
// 仕様書: .docs/VBT_GroundTruth_Tool_Spec.md §8 セッション一括エクスポート型
//   - エクスポート対象はセッションフォルダ URL 単一
//   - zip 化はおこなわない（必要なら後段 Python 側で実施）→ URL のみを共有
//
// Clean Architecture:
//   - Framework & Drivers 層（UIKit 隔離）
//   - 共有完了コールバックでユーザー操作（AirDrop / Files / iCloud / キャンセル）を捕捉
struct VBTShareSheetView: UIViewControllerRepresentable {

    /// 共有対象のセッションフォルダ URL（zip 化せずフォルダのまま）。
    let activityItems: [Any]

    /// 完了コールバック。`activityType` が nil の場合はキャンセル扱い。
    /// 親 View 側で `isPresented = false` 等のクリーンアップに利用する。
    var completion: ((UIActivity.ActivityType?, Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = { activityType, completed, _, _ in
            completion?(activityType, completed)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // activity items は presentation サイクル毎に固定。更新不要。
    }
}
