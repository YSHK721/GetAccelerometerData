// VBT Motion Replay PoC Phase 4: Apple Watch 形状を SceneKit ノード階層として供給する。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §8.3
//
// 責務:
//   親ノード "watch" 1 つを返す。`build()` は以下の優先順で構築する。
//     1. バンドル同梱の OBJ アセット（Resources/MotionReplay/AppleWatch.obj）をロード
//     2. ロード失敗時は従来の手続き構築（SCNBox / SCNPlane / SCNCylinder 組合せ）にフォールバック
//   親ノードに `simdOrientation` を適用すれば全体姿勢が回転する。
//
// 座標系:
//   SceneKit 既定の右手系（X=右, Y=上, Z=前面方向）。単位は m（メートル）。
//   手続き構築では画面法線=+Z、上端=+Y で配置する。OBJ モデルの自然向きはアセットに依存し、
//   `normalizeLoadedModel()` で原点を bbox 中心に揃え、1 unit = 1mm 想定で 0.001 倍にスケールする。
//   方向回転は親側（MotionReplaySceneView の `simdOrientation`）で吸収する設計とする。
//
// ガード方針:
//   ファイル全体を `#if canImport(UIKit) && os(iOS)` でガードし、
//   macOS テストランナーから不可視にする（SceneKit/UIKit/ModelIO 依存のため）。

#if canImport(UIKit) && os(iOS)
import UIKit
import SceneKit
import ModelIO
import SceneKit.ModelIO

public enum WatchSceneNodeBuilder {

    // MARK: - Public API

    /// ルートノード名。`SCNScene.rootNode.childNode(withName:)` で参照する側もこの定数を使うこと。
    /// 文字列リテラル散在による typo silent no-op を防ぐ目的。
    public static let rootNodeName = "watch"

    /// Apple Watch を模した SCNNode 階層を組み立てて返す。
    /// OBJ アセット（`Resources/MotionReplay/AppleWatch.obj`）が利用可能ならそれをロードし、
    /// 失敗時は従来の手続き構築（`buildProcedural()`）にフォールバックする。
    /// 返値ノードの `.name` は `rootNodeName`。
    ///
    /// パフォーマンス:
    ///   OBJ パース（5.2MB / 39549 頂点）は初回のみ実行し、テンプレートノードを `cachedOBJTemplate`
    ///   に保持する。以降は `clone()` で複製を返すため `makeUIView` 再呼出（SwiftUI 再構築）時の
    ///   メイン同期ヒッチを回避する。
    public static func build() -> SCNNode {
        if let template = cachedOBJTemplate {
            return template.clone()
        }
        return buildProcedural()
    }

    /// OBJ ロード結果のキャッシュ。初回参照時に `loadOBJModel()` を 1 度だけ実行する。
    /// nil の場合は OBJ ロード不能（未配置 / 破損 / ジオメトリ空）。
    ///
    /// Swift 6 concurrency:
    ///   `SCNNode` は非 Sendable のため `nonisolated(unsafe)` で明示オプトアウト。
    ///   テンプレートは read-only として扱い、利用側は必ず `clone()` で複製するため
    ///   共有可変状態は発生しない。SceneKit API はメインスレッドで使う前提（呼び出し側
    ///   `MotionReplaySceneView.makeUIView(_:)` は MainActor 上で実行される）。
    nonisolated(unsafe) private static let cachedOBJTemplate: SCNNode? = loadOBJModel()

    /// 従来の手続き構築（Series 9 41mm 相当）。OBJ ロード失敗時のフォールバック。
    /// 子ノードは `watchBody / watchScreen / crown / bandUpper / bandLower`。
    public static func buildProcedural() -> SCNNode {
        let watch = SCNNode()
        watch.name = rootNodeName

        watch.addChildNode(makeBody())
        watch.addChildNode(makeScreen())
        watch.addChildNode(makeCrown())
        watch.addChildNode(makeBandUpper())
        watch.addChildNode(makeBandLower())

        return watch
    }

    // MARK: - OBJ Loading

    /// バンドル同梱の OBJ をロードし、`rootNodeName` のラッパーノードに包んで返す。
    /// アセット未配置・ロード失敗・ジオメトリ空のいずれかでも nil を返し、呼び出し側はフォールバックする。
    /// 各失敗分岐は DEBUG ビルドでログ出力し、フォールバック発動の観測性を確保する。
    ///
    /// 注意:
    ///   SwiftPM の `.process("Resources")` はディレクトリ構造をフラット化してバンドル直下に配置する。
    ///   ソース上は `Resources/MotionReplay/AppleWatch.obj` に置いてあっても、バンドル内のパスは
    ///   ルート直下 `AppleWatch.obj` になるため、`subdirectory:` を指定すると nil が返る。
    private static func loadOBJModel() -> SCNNode? {
        guard let url = Bundle.module.url(
            forResource: "AppleWatch",
            withExtension: "obj"
        ) else {
            debugLogFallback(reason: "OBJ resource not found in bundle (expected: AppleWatch.obj at bundle root)")
            return nil
        }

        let asset = MDLAsset(url: url)
        guard asset.count > 0 else {
            debugLogFallback(reason: "MDLAsset returned empty asset (count=0) for \(url.lastPathComponent)")
            return nil
        }

        let scene = SCNScene(mdlAsset: asset)
        let watch = SCNNode()
        watch.name = rootNodeName

        // SCNScene の rootNode 直下の子をラッパーに移し替える
        for child in scene.rootNode.childNodes {
            child.removeFromParentNode()
            watch.addChildNode(child)
        }

        guard !watch.childNodes.isEmpty else {
            debugLogFallback(reason: "SCNScene from MDLAsset had no child geometry nodes")
            return nil
        }

        normalizeLoadedModel(watch)
        return watch
    }

    /// DEBUG ビルドのみフォールバック理由を stderr に出力する。本番ビルドでは無音。
    private static func debugLogFallback(reason: String) {
        #if DEBUG
        print("[WatchSceneNodeBuilder] OBJ load failed → procedural fallback. Reason: \(reason)")
        #endif
    }

    /// ロード直後のモデルを「原点中心・メートル単位」に正規化する。
    /// - 原点: 子ノード全体の bbox 中心に揃える（`pivot` 平行移動で実現）
    /// - スケール: bbox の最大辺長が `targetMaxExtentMeters` になるよう動的に算出（procedural と
    ///   同等の画面占有サイズを保つことでカメラ・ライト構成の調整を不要にする）
    /// - 軸回転は適用しない（親側で吸収）
    /// - マテリアル: ワイヤーフレーム表示に統一（参照画像の青ワイヤー外観に合わせる）
    private static func normalizeLoadedModel(_ node: SCNNode) {
        let (minVec, maxVec) = aggregateBoundingBox(of: node)
        let center = SCNVector3(
            (minVec.x + maxVec.x) * 0.5,
            (minVec.y + maxVec.y) * 0.5,
            (minVec.z + maxVec.z) * 0.5
        )
        node.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)

        let maxExtent = max(
            maxVec.x - minVec.x,
            maxVec.y - minVec.y,
            maxVec.z - minVec.z
        )
        let scale: Float = maxExtent > 0 ? (targetMaxExtentMeters / maxExtent) : loadedModelFallbackScale
        node.scale = SCNVector3(scale, scale, scale)

        applyWireframeMaterial(to: node)
    }

    /// 子孫すべてのジオメトリにワイヤーフレーム表示マテリアルを適用し、
    /// `wireframeTriangleStride > 1` の場合は三角形をサブサンプリングして線量を減らす。
    /// 既存マテリアルがあれば `fillMode = .lines` を上書きし、`diffuse` を青に統一する。
    /// マテリアル未定義のジオメトリには新規 SCNMaterial を生成して付与する。
    private static func applyWireframeMaterial(to node: SCNNode) {
        if let geometry = node.geometry {
            if geometry.materials.isEmpty {
                geometry.materials = [makeWireframeMaterial()]
            } else {
                for material in geometry.materials {
                    material.fillMode = .lines
                    material.diffuse.contents = wireframeColor
                    material.lightingModel = .constant
                    material.isDoubleSided = true
                }
            }
            if wireframeTriangleStride > 1 {
                node.geometry = decimatedGeometry(geometry, triangleStride: wireframeTriangleStride)
            }
        }
        for child in node.childNodes {
            applyWireframeMaterial(to: child)
        }
    }

    private static func makeWireframeMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.fillMode = .lines
        material.diffuse.contents = wireframeColor
        material.lightingModel = .constant
        material.isDoubleSided = true
        return material
    }

    /// 三角形を `triangleStride` 個おきに 1 個ずつ残した SCNGeometry を生成する。
    /// 頂点ソース（位置・法線・UV）は維持し、SCNGeometryElement のインデックスバッファのみ間引く。
    /// 三角形以外のプリミティブ（line / point 等）はそのまま温存する。
    private static func decimatedGeometry(_ source: SCNGeometry, triangleStride: Int) -> SCNGeometry {
        let newElements: [SCNGeometryElement] = source.elements.map { element in
            guard element.primitiveType == .triangles, element.primitiveCount > 0 else {
                return element
            }
            let bytesPerIndex = element.bytesPerIndex
            let bytesPerTriangle = bytesPerIndex * 3
            let srcData = element.data
            var dstData = Data()
            dstData.reserveCapacity((element.primitiveCount / triangleStride + 1) * bytesPerTriangle)
            for triIdx in Swift.stride(from: 0, to: element.primitiveCount, by: triangleStride) {
                let offset = triIdx * bytesPerTriangle
                guard offset + bytesPerTriangle <= srcData.count else { break }
                dstData.append(srcData.subdata(in: offset..<(offset + bytesPerTriangle)))
            }
            return SCNGeometryElement(
                data: dstData,
                primitiveType: .triangles,
                primitiveCount: dstData.count / bytesPerTriangle,
                bytesPerIndex: bytesPerIndex
            )
        }
        let result = SCNGeometry(sources: source.sources, elements: newElements)
        result.materials = source.materials
        result.name = source.name
        return result
    }

    /// 子孫ノードの geometry を再帰的に集約した bbox を返す。
    /// SCNNode.boundingBox は実装によって子孫を含まないケースがあるため、ローカル変換を考慮した手計算で求める。
    private static func aggregateBoundingBox(of root: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
        var minVec = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxVec = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        var found = false

        func visit(_ node: SCNNode, parentTransform: SCNMatrix4) {
            let world = SCNMatrix4Mult(node.transform, parentTransform)
            if let geometry = node.geometry {
                let (gMin, gMax) = geometry.boundingBox
                let corners: [SCNVector3] = [
                    SCNVector3(gMin.x, gMin.y, gMin.z),
                    SCNVector3(gMax.x, gMin.y, gMin.z),
                    SCNVector3(gMin.x, gMax.y, gMin.z),
                    SCNVector3(gMax.x, gMax.y, gMin.z),
                    SCNVector3(gMin.x, gMin.y, gMax.z),
                    SCNVector3(gMax.x, gMin.y, gMax.z),
                    SCNVector3(gMin.x, gMax.y, gMax.z),
                    SCNVector3(gMax.x, gMax.y, gMax.z)
                ]
                let m = simd_float4x4(world)
                for c in corners {
                    let v = m * SIMD4<Float>(c.x, c.y, c.z, 1)
                    minVec = SCNVector3(min(minVec.x, v.x), min(minVec.y, v.y), min(minVec.z, v.z))
                    maxVec = SCNVector3(max(maxVec.x, v.x), max(maxVec.y, v.y), max(maxVec.z, v.z))
                    found = true
                }
            }
            for child in node.childNodes {
                visit(child, parentTransform: world)
            }
        }

        visit(root, parentTransform: SCNMatrix4Identity)

        if !found {
            return (SCNVector3Zero, SCNVector3Zero)
        }
        return (minVec, maxVec)
    }

    /// ロード後モデルの目標最大辺長（m）。procedural fallback の総 Y 寸法 (本体+バンド) と概ね同等。
    /// 動的スケール算出に失敗した場合のみ `loadedModelFallbackScale` が使われる。
    ///
    /// 公開理由:
    ///   `MotionReplaySceneView` がこの値を参照してカメラ距離を比例算出することで、
    ///   サイズ変更時のパース歪み（カメラが相対的に近づきすぎることによる魚眼ライクな湾曲）を防ぐ。
    public static let targetMaxExtentMeters: Float = 0.35

    /// bbox 計測失敗時のフォールバックスケール（1 OBJ unit = 1 mm 想定）
    private static let loadedModelFallbackScale: Float = 0.001

    /// ワイヤーフレーム表示色（参照画像準拠の青）
    private static let wireframeColor = UIColor.systemBlue

    /// ワイヤーフレーム表示時の三角形サブサンプリングストライド（線量調整ノブ）。
    /// - 1 = 全三角形を描画（OBJ のフル密度, 約 39549 三角形分の辺）
    /// - 2 = 半分の三角形のみ描画（線量約 50%）
    /// - 3 = 三分の一（線量約 33%）
    /// - N = 1/N（線量約 100/N %）
    /// 値を大きくするほど画面がすっきりするが、シルエットの輪郭精度が落ちる。
    /// 線量を「増やす」には OBJ 自体のポリゴン分割が必要（本パラメータでは増やせない）。
    private static let wireframeTriangleStride: Int = 1

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
