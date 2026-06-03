// VBT Motion Replay PoC Phase 4: SwiftUI から SceneKit を駆動する UIViewRepresentable。
// 内部設計書: .docs/07_vbt_motion_replay_internal_design.md §8.3
//
// 責務:
//   SCNView をラップし、外部から与えられた AttitudeQuaternion を Watch ノードに反映する。
//   PoC ではカメラ固定（allowsCameraControl = false）、固定 2 ライト構成。
//
// ガード方針:
//   ファイル全体を `#if canImport(UIKit) && os(iOS)` でガードし、
//   macOS テストランナーから不可視にする（SwiftUI/UIKit/SceneKit 依存のため）。

#if canImport(UIKit) && os(iOS)
import SwiftUI
import SceneKit
import simd

public struct MotionReplaySceneView: UIViewRepresentable {

    public let orientation: AttitudeQuaternion

    public init(orientation: AttitudeQuaternion) {
        self.orientation = orientation
    }

    // MARK: - UIViewRepresentable

    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        // 暗灰色の背景: Watch 本体（ダークグレー）と十分なコントラスト
        scnView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        // 明示ライト構成で十分明るいため、デフォルトライトは無効化（重畳による washed out 回避）
        scnView.autoenablesDefaultLighting = false
        // PoC: カメラは固定（ユーザー操作不可）
        scnView.allowsCameraControl = false

        let scene = SCNScene()
        scnView.scene = scene

        // Watch ノード階層を追加
        scene.rootNode.addChildNode(WatchSceneNodeBuilder.build())

        // ライト・カメラを追加し、明示的に rendering camera を指定
        scene.rootNode.addChildNode(makeAmbientLightNode())
        scene.rootNode.addChildNode(makeDirectionalLightNode())
        let cameraNode = makeCameraNode()
        scene.rootNode.addChildNode(cameraNode)
        // 明示的に pointOfView を設定（自動検出に依存しない）
        scnView.pointOfView = cameraNode

        return scnView
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        guard
            let watch = uiView.scene?.rootNode.childNode(
                withName: WatchSceneNodeBuilder.rootNodeName,
                recursively: false
            )
        else {
            // nil ガード: watch ノードが見つからない場合は何もしない
            // Debug ビルドでは早期発見のため assertionFailure
            #if DEBUG
            assertionFailure("watch node not found in scene root")
            #endif
            return
        }
        // double → float ダウンキャストで simdOrientation を更新
        // simd_quatf は simd_quatd からの直接変換 init を提供しないため、
        // simd_float4 (ix, iy, iz, r) 経由で手動ダウンキャストする
        let qd = orientation.simdValue
        let vector = simd_float4(
            Float(qd.imag.x),
            Float(qd.imag.y),
            Float(qd.imag.z),
            Float(qd.real)
        )
        watch.simdOrientation = simd_quatf(vector: vector)
    }

    // MARK: - Lights & Camera

    private func makeAmbientLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .ambient
        // 暗いダークグレーマテリアル + 黒/暗灰背景でも視認できる明るさに引き上げ
        light.intensity = 800
        light.color = UIColor.white

        let node = SCNNode()
        node.name = "ambientLight"
        node.position = SCNVector3(0, 0, 0)
        node.light = light
        return node
    }

    private func makeDirectionalLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .directional
        light.intensity = 700

        let node = SCNNode()
        node.name = "directionalLight"
        node.light = light
        // (-1, -1, -1) 方向近似: X / Y 各々 -π/4 で前下方向を照らす
        node.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 4, 0)
        return node
    }

    private func makeCameraNode() -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        // 近接面・遠面を明示的に設定（既定値で Watch サイズ 0.04m がクリップされる可能性を排除）
        camera.zNear = 0.001
        camera.zFar = 10

        let node = SCNNode()
        node.name = "camera"
        node.camera = camera
        // バンド込み全高 0.155m を視野内に余裕を持って収めるため、縦長端末でも切れない位置まで後退。
        // FOV 60° at z=0.4 で可視高さ = 2 * 0.4 * tan(30°) ≈ 0.462m → Watch 0.155m は約 33% で余裕。
        node.position = SCNVector3(0, 0, 0.4)
        node.look(at: SCNVector3(0, 0, 0))
        return node
    }
}
#endif
