// VBT Motion Replay PoC Phase 4: Apple Watch Series 9 41mm 形状を模した SceneKit ノード階層構築。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §8.3
//
// 責務:
//   SCNNode 階層（本体・画面・Crown・上下バンド）を組み立てる純粋関数のみを提供。
//   親ノード "watch" 1 つを返す。子に本体・画面・Crown・上下バンドを保持し、
//   親ノードに `simdOrientation` を適用すれば全体姿勢が回転する。
//
// 座標系:
//   SceneKit 既定の右手系（X=右, Y=上, Z=前面方向）。単位は m（メートル）。
//   Watch の画面法線は +Z 方向、上端は +Y 方向に配置する。
//
// ガード方針:
//   ファイル全体を `#if canImport(UIKit) && os(iOS)` でガードし、
//   macOS テストランナーから不可視にする（SceneKit/UIKit 依存のため）。

#if canImport(UIKit) && os(iOS)
import UIKit
import SceneKit

public enum WatchSceneNodeBuilder {

    // MARK: - Public API

    /// ルートノード名。`SCNScene.rootNode.childNode(withName:)` で参照する側もこの定数を使うこと。
    /// 文字列リテラル散在による typo silent no-op を防ぐ目的。
    public static let rootNodeName = "watch"

    /// Apple Watch Series 9 41mm を模した SCNNode 階層を組み立てて返す。
    /// 返値ノードの `.name` は `rootNodeName`。子ノードは `watchBody / watchScreen / crown / bandUpper / bandLower`。
    public static func build() -> SCNNode {
        let watch = SCNNode()
        watch.name = rootNodeName

        watch.addChildNode(makeBody())
        watch.addChildNode(makeScreen())
        watch.addChildNode(makeCrown())
        watch.addChildNode(makeBandUpper())
        watch.addChildNode(makeBandLower())

        return watch
    }

    // MARK: - Dimensions (m)

    private static let bodyWidth: CGFloat = 0.041
    private static let bodyHeight: CGFloat = 0.035
    private static let bodyLength: CGFloat = 0.0107
    private static let bodyChamfer: CGFloat = 0.005

    private static let screenWidth: CGFloat = 0.033
    private static let screenHeight: CGFloat = 0.028
    /// 裏抜け防止のための画面 z オフセット
    private static let screenZOffset: CGFloat = 0.0001

    private static let crownRadius: CGFloat = 0.004
    private static let crownHeight: CGFloat = 0.008

    private static let bandWidth: CGFloat = 0.020
    private static let bandHeight: CGFloat = 0.060
    private static let bandLength: CGFloat = 0.005
    private static let bandChamfer: CGFloat = 0.002
    /// バンド中心の y オフセット（本体上下端から派生）
    private static let bandCenterY: CGFloat = 0.0475

    // MARK: - Colors

    /// ダークグレー #3A3A3D（本体）
    private static let bodyColor = UIColor(red: 0.23, green: 0.23, blue: 0.24, alpha: 1.0)
    /// #48484A（バンド）
    private static let bandColor = UIColor(red: 0.28, green: 0.28, blue: 0.29, alpha: 1.0)
    /// 向き識別印（画面中央の上向き三角形）
    private static let orientationMarkColor = UIColor.green
    /// 向き識別印 三角形の外接半径
    private static let orientationMarkRadius: CGFloat = 0.005

    // MARK: - Node Factories

    private static func makeBody() -> SCNNode {
        let geometry = SCNBox(
            width: bodyWidth,
            height: bodyHeight,
            length: bodyLength,
            chamferRadius: bodyChamfer
        )
        geometry.firstMaterial?.diffuse.contents = bodyColor

        let node = SCNNode(geometry: geometry)
        node.name = "watchBody"
        return node
    }

    private static func makeScreen() -> SCNNode {
        let plane = SCNPlane(width: screenWidth, height: screenHeight)
        plane.firstMaterial?.diffuse.contents = UIColor.black

        let node = SCNNode(geometry: plane)
        node.name = "watchScreen"
        // 本体前面 + 微小オフセットで配置（裏抜け防止）
        node.position = SCNVector3(0, 0, Float(bodyLength / 2 + screenZOffset))

        // 向き識別印（緑の上向き三角形）を画面中央に追加
        node.addChildNode(makeOrientationMark())
        return node
    }

    /// 向き識別印として小さな緑色の上向き三角形を生成。
    /// 三角形は Y 上方向を頂点とし、外接半径 `orientationMarkRadius`。
    private static func makeOrientationMark() -> SCNNode {
        let r = orientationMarkRadius
        let path = UIBezierPath()
        // 上頂点
        path.move(to: CGPoint(x: 0, y: r))
        // 左下
        path.addLine(to: CGPoint(x: -r * 0.866, y: -r * 0.5))
        // 右下
        path.addLine(to: CGPoint(x: r * 0.866, y: -r * 0.5))
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0)
        shape.firstMaterial?.diffuse.contents = orientationMarkColor

        let node = SCNNode(geometry: shape)
        node.name = "orientationMark"
        // 画面プレーンより僅かに前面に配置（Z ファイティング回避）
        node.position = SCNVector3(0, 0, Float(screenZOffset))
        return node
    }

    private static func makeCrown() -> SCNNode {
        let cylinder = SCNCylinder(radius: crownRadius, height: crownHeight)
        cylinder.firstMaterial?.diffuse.contents = UIColor.lightGray

        let node = SCNNode(geometry: cylinder)
        node.name = "crown"
        // 本体右側面、上部寄り
        node.position = SCNVector3(
            Float(bodyWidth / 2 + crownRadius),
            0.010,
            0
        )
        // 円筒軸（既定 Y）を X 方向に向ける
        node.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        return node
    }

    private static func makeBandUpper() -> SCNNode {
        let node = SCNNode(geometry: makeBandGeometry())
        node.name = "bandUpper"
        node.position = SCNVector3(0, Float(bandCenterY), 0)
        return node
    }

    private static func makeBandLower() -> SCNNode {
        let node = SCNNode(geometry: makeBandGeometry())
        node.name = "bandLower"
        node.position = SCNVector3(0, -Float(bandCenterY), 0)
        return node
    }

    private static func makeBandGeometry() -> SCNBox {
        let box = SCNBox(
            width: bandWidth,
            height: bandHeight,
            length: bandLength,
            chamferRadius: bandChamfer
        )
        box.firstMaterial?.diffuse.contents = bandColor
        return box
    }
}
#endif
