import Foundation

// MARK: - LabelingSkinKind
// VBT Labeling 画面の見た目バリエーション（5 種類）の識別子。
// 既存 VBTLabelingView / VBTLabelingViewModel は無変更で、本 enum を用いた
// VBTLabelingSkinnedView 経由でスキンを切り替える。
public enum LabelingSkinKind: String, CaseIterable, Identifiable {
    case classic
    case compact
    case darkPro
    case chartCentric
    case cardBased

    public var id: String { rawValue }

    /// Picker 表示用の日本語/英語混在ラベル。
    public var displayName: String {
        switch self {
        case .classic:      return "Classic"
        case .compact:      return "Compact"
        case .darkPro:      return "Dark Pro"
        case .chartCentric: return "Chart 中心"
        case .cardBased:    return "Card"
        }
    }
}
