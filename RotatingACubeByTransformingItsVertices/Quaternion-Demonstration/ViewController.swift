/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates differetent quaternion use cases.
*/

import UIKit
import simd
import SceneKit

class ViewController: UIViewController {

    enum DemoMode: String {
        case simpleRotation = "Simple"
        case compositeRotation = "Composite"
        case sphericalInterpolate = "Spherical"
        case splineInterpolate = "Spline"
        case splineRotationIn3D = "Cube: spline"
        case slerpRotationIn3D = "Cube: slerp"
    }

    var mode: DemoMode = .simpleRotation {
        didSet {
            switchDemo()
        }
    }

    @IBOutlet var sceneKitView: SCNView!
    @IBOutlet weak var toolbar: UIToolbar!

    let defaultColor = UIColor.orange

    let modeSegmentedControlItem: UIBarButtonItem = {
        let segmentedControl = UISegmentedControl(items: [DemoMode.simpleRotation.rawValue,
                                                          DemoMode.compositeRotation.rawValue,
                                                          DemoMode.sphericalInterpolate.rawValue,
                                                          DemoMode.splineInterpolate.rawValue,
                                                          DemoMode.slerpRotationIn3D.rawValue,
                                                          DemoMode.splineRotationIn3D.rawValue])

        segmentedControl.selectedSegmentIndex = 0

        segmentedControl.addTarget(self,
                                   action: #selector(modeSegmentedControlChangeHandler),
                                   for: .valueChanged)

        return UIBarButtonItem(customView: segmentedControl)
    }()

    lazy var scene = setupSceneKit()

    override func viewDidLoad() {
        super.viewDidLoad()

        toolbar.setItems([modeSegmentedControlItem,
                          UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.play,
                                          target: self,
                                          action: #selector(runButtonTouchHandler))],
                         animated: false)

        switchDemo()
    }

    func switchDemo() {
        scene = setupSceneKit()
        isRunning = false
        displaylink?.invalidate()

        switch mode {
        case .simpleRotation:
            simpleRotation()
        case .compositeRotation:
            compositeRotation()
        case .sphericalInterpolate:
            sphericalInterpolate()
        case .splineInterpolate:
            splineInterpolate()
        case .splineRotationIn3D:
            vertexRotation(useSpline: true)
        case .slerpRotationIn3D:
            vertexRotation(useSpline: false)
        }
    }

    @objc
    func runButtonTouchHandler() {
        switchDemo()
        isRunning = true
    }

    @objc
    func modeSegmentedControlChangeHandler(segmentedControl: UISegmentedControl) {
        guard
            let newModeName = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex),
            let newMode = DemoMode(rawValue: newModeName) else {
                return
        }

        mode = newMode
    }

    var isRunning: Bool = false {
        didSet {
            toolbar.isUserInteractionEnabled = !isRunning
            toolbar.alpha = isRunning ? 0.5 : 1

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5

            SCNTransaction.commit()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
         return .bottom
    }

    // MARK: Demos

    var displaylink: CADisplayLink?

    // MARK: Simple Rotation Demo

    var angle: Float = 0
    let originVector = simd_float3(0, 0, 1)
    var previousSphere: SCNNode?

    func simpleRotation() {
        addMainSphere(scene: scene)

        angle = 0
        previousSphere = nil

        addSphereAt(position: originVector,
                    radius: 0.04,
                    color: .red,
                    scene: scene)

        displaylink = CADisplayLink(target: self,
                                    selector: #selector(simpleRotationStep))

        displaylink?.add(to: .current,
                         forMode: .default)
    }

    @objc
    func simpleRotationStep(displaylink: CADisplayLink) {
        guard isRunning else {
            return
        }

        previousSphere?.removeFromParentNode()

        angle -= 1

        let quaternion = simd_quatf(angle: degreesToRadians(angle),
                                    axis: simd_float3(x: 1,
                                                      y: 0,
                                                      z: 0))

        let rotatedVector = quaternion.act(originVector)

        previousSphere = addSphereAt(position: rotatedVector,
                                     radius: 0.04,
                                     color: defaultColor,
                                     scene: scene)

        if angle < -60 {
            displaylink.invalidate()
            isRunning = false
        }
    }

    // MARK: Composite Rotation Demo

    // `previousSphereA` and `previousSphereB` show component quaternions
    var previousSphereA: SCNNode?
    var previousSphereB: SCNNode?

    func compositeRotation() {
        addMainSphere(scene: scene)

        angle = 0
        previousSphere = nil
        previousSphereA = nil
        previousSphereB = nil

        addSphereAt(position: originVector,
                    radius: 0.04,
                    color: .red,
                    scene: scene)

        displaylink = CADisplayLink(target: self,
                                    selector: #selector(compositeRotationStep))

        displaylink?.add(to: .current,
                         forMode: .default)
    }

    @objc
    func compositeRotationStep(displaylink: CADisplayLink) {
        guard isRunning else {
            return
        }

        previousSphere?.removeFromParentNode()
        previousSphereA?.removeFromParentNode()
        previousSphereB?.removeFromParentNode()

        angle -= 1

        let quaternionA = simd_quatf(angle: degreesToRadians(angle),
                                     axis: simd_float3(x: 1,
                                                       y: 0,
                                                       z: 0))

        let quaternionB = simd_quatf(angle: degreesToRadians(angle),
                                     axis: simd_normalize(simd_float3(x: 0,
                                                                      y: -0.75,
                                                                      z: -0.5)))

        let rotatedVectorA = quaternionA.act(originVector)
        previousSphereA = addSphereAt(position: rotatedVectorA,
                                      radius: 0.02,
                                      color: .green,
                                      scene: scene)

        let rotatedVectorB = quaternionB.act(originVector)
        previousSphereB = addSphereAt(position: rotatedVectorB,
                                      radius: 0.02,
                                      color: .red,
                                      scene: scene)

        let quaternion = quaternionA * quaternionB

        let rotatedVector = quaternion.act(originVector)

        previousSphere = addSphereAt(position: rotatedVector,
                                     radius: 0.04,
                                     color: defaultColor,
                                     scene: scene)

        if angle <= -360 {
            displaylink.invalidate()
            isRunning = false
        }
    }

    // MARK: Spherical Interpolate Demo

    var sphericalInterpolateTime: Float = 0

    let origin = simd_float3(0, 0, 1)

    let q0 = simd_quatf(angle: .pi / 6,
                        axis: simd_float3(x: 0,
                                          y: -1,
                                          z: 0))

    let q1 = simd_quatf(angle: .pi / 6,
                        axis: simd_normalize(simd_float3(x: -1,
                                                         y: 1,
                                                         z: 0)))

    let q2 = simd_quatf(angle: .pi / 20,
                        axis: simd_normalize(simd_float3(x: 1,
                                                         y: 0,
                                                         z: -1)))

    func sphericalInterpolate() {
        addMainSphere(scene: scene)

        sphericalInterpolateTime = 0

        let u0 = simd_act(q0, origin)
        let u1 = simd_act(q1, origin)
        let u2 = simd_act(q2, origin)

        for u in [u0, u1, u2] {
            addSphereAt(position: u,
                        radius: 0.04,
                        color: defaultColor,
                        scene: scene)
        }

        displaylink = CADisplayLink(target: self,
                                    selector: #selector(sphericalInterpolateStep))

        displaylink?.add(to: .current,
                         forMode: .default)

        previousShortestInterpolationPoint = nil
        previousLongestInterpolationPoint = nil

    }

    var previousShortestInterpolationPoint: simd_float3?
    var previousLongestInterpolationPoint: simd_float3?

    @objc
    func sphericalInterpolateStep(displaylink: CADisplayLink) {
        guard isRunning else {
            return
        }

        let increment: Float = 0.005
        sphericalInterpolateTime += increment

        // simd_slerp
        do {
            let q = simd_slerp(q0, q1, sphericalInterpolateTime)
            let interpolationPoint = simd_act(q, origin)
            if let previousShortestInterpolationPoint = previousShortestInterpolationPoint {
                addLineBetweenVertices(vertexA: previousShortestInterpolationPoint,
                                       vertexB: interpolationPoint,
                                       inScene: scene)
            }
            previousShortestInterpolationPoint = interpolationPoint
        }

        // simd_slerp_longest
        do {
            for t in [sphericalInterpolateTime,
                      sphericalInterpolateTime + increment * 0.5] {
                        let q = simd_slerp_longest(q1, q2, t)
                        let interpolationPoint = simd_act(q, origin)
                        if let previousLongestInterpolationPoint = previousLongestInterpolationPoint {
                            addLineBetweenVertices(vertexA: previousLongestInterpolationPoint,
                                                   vertexB: interpolationPoint,
                                                   inScene: scene)
                        }
                        previousLongestInterpolationPoint = interpolationPoint
            }
        }

        if !(sphericalInterpolateTime < 1) {
            displaylink.invalidate()
            isRunning = false
        }
    }

    // MARK: Spline Interpolate Demo

    var splineInterpolateTime: Float = 0
    var rotations = [simd_quatf]()
    var markers = [SCNNode]()

    var index = 0 {
        didSet {
            if !markers.isEmpty {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                if oldValue < markers.count {
                    markers[oldValue].geometry?.firstMaterial?.diffuse.contents = defaultColor
                }
                if index < markers.count {
                    markers[index].geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
                }
                SCNTransaction.commit()
            }
        }
    }

    func splineInterpolate() {
        rotations.removeAll()

        let origin = simd_float3(0, 0, 1)
        let q_origin = simd_quatf(angle: 0,
                                  axis: simd_float3(x: 1, y: 0, z: 0))

        rotations.append(q_origin)

        let markerCount = 12
        markers.removeAll()

        for i in 0 ... markerCount {
            let angle = (.pi * 2) / Float(markerCount) * Float(i)
            let latitudeRotation = simd_quatf(angle: (angle - .pi / 2) * 0.3,
                                              axis: simd_normalize(simd_float3(x: 0,
                                                                               y: 1,
                                                                               z: 0)))

            let longitudeRotation = simd_quatf(angle: .pi / 4 * .random(in: 0...0.25) * Float(i % 2 == 0 ? -1 : 1),
                                               axis: simd_normalize(simd_float3(x: 1,
                                                                                y: 0,
                                                                                z: 0)))

            let q = latitudeRotation * longitudeRotation

            let u = simd_act(q, origin)

            rotations.append(q)

            if  i != markerCount {
                markers.append(addSphereAt(position: u,
                                           radius: 0.01,
                                           color: defaultColor,
                                           scene: scene))
            }
        }

        addMainSphere(scene: scene)

        splineInterpolateTime = 0
        index = 1

        displaylink = CADisplayLink(target: self,
                                    selector: #selector(splineInterpolateStep))

        displaylink?.add(to: .current,
                         forMode: .default)

        previousSplinePoint = nil
    }

    var previousSplinePoint: simd_float3?

    @objc
    func splineInterpolateStep(displaylink: CADisplayLink) {
        guard isRunning else {
            return
        }

        let increment: Float = 0.04
        splineInterpolateTime += increment

        let q = simd_spline(rotations[index - 1],
                            rotations[index],
                            rotations[index + 1],
                            rotations[index + 2],
                            splineInterpolateTime)

        let splinePoint = simd_act(q, origin)

        if let previousSplinePoint = previousSplinePoint {
            addLineBetweenVertices(vertexA: previousSplinePoint,
                                   vertexB: splinePoint,
                                   inScene: scene)
        }

        previousSplinePoint = splinePoint

        if !(splineInterpolateTime < 1) {
            index += 1
            splineInterpolateTime = 0

            if index > rotations.count - 3 {
                displaylink.invalidate()
                isRunning = false
            }
        }
    }

    // MARK: Rotating vertices in 3D

    let vertexRotations: [simd_quatf] = [
        simd_quatf(angle: 0,
                   axis: simd_normalize(simd_float3(x: 0, y: 0, z: 1))),
        simd_quatf(angle: 0,
                   axis: simd_normalize(simd_float3(x: 0, y: 0, z: 1))),
        simd_quatf(angle: .pi * 0.05,
                   axis: simd_normalize(simd_float3(x: 0, y: 1, z: 0))),
        simd_quatf(angle: .pi * 0.1,
                   axis: simd_normalize(simd_float3(x: 1, y: 0, z: -1))),
        simd_quatf(angle: .pi * 0.15,
                   axis: simd_normalize(simd_float3(x: 0, y: 1, z: 0))),
        simd_quatf(angle: .pi * 0.2,
                   axis: simd_normalize(simd_float3(x: -1, y: 0, z: 1))),
        simd_quatf(angle: .pi * 0.15,
                   axis: simd_normalize(simd_float3(x: 0, y: -1, z: 0))),
        simd_quatf(angle: .pi * 0.1,
                   axis: simd_normalize(simd_float3(x: 1, y: 0, z: -1))),
        simd_quatf(angle: .pi * 0.05,
                   axis: simd_normalize(simd_float3(x: 0, y: 1, z: 0))),
        simd_quatf(angle: 0,
                   axis: simd_normalize(simd_float3(x: 0, y: 0, z: 1))),
        simd_quatf(angle: 0,
                   axis: simd_normalize(simd_float3(x: 0, y: 0, z: 1)))
    ]

    var vertexRotationUsesSpline = true
    var vertexRotationIndex = 0
    var vertexRotationTime: Float = 0
    var previousCube: SCNNode?
    var previousVertexMarker: SCNNode?

    let cubeVertexOrigins: [simd_float3] = [
        simd_float3(x: -0.5, y: -0.5, z: 0.5),
        simd_float3(x: 0.5, y: -0.5, z: 0.5),
        simd_float3(x: -0.5, y: -0.5, z: -0.5),
        simd_float3(x: 0.5, y: -0.5, z: -0.5),
        simd_float3(x: -0.5, y: 0.5, z: 0.5),
        simd_float3(x: 0.5, y: 0.5, z: 0.5),
        simd_float3(x: -0.5, y: 0.5, z: -0.5),
        simd_float3(x: 0.5, y: 0.5, z: -0.5)
        ]

    lazy var cubeVertices = cubeVertexOrigins

    let sky = MDLSkyCubeTexture(name: "sky",
                                channelEncoding: MDLTextureChannelEncoding.float16,
                                textureDimensions: simd_int2(x: 128, y: 128),
                                turbidity: 0.5,
                                sunElevation: 0.5,
                                sunAzimuth: 0.5,
                                upperAtmosphereScattering: 0.5,
                                groundAlbedo: 0.5)

    func vertexRotation(useSpline: Bool) {
        scene.lightingEnvironment.contents = sky
        scene.rootNode.childNode(withName: "cameraNode",
                                 recursively: false)?.camera?.usesOrthographicProjection = false

        vertexRotationUsesSpline = useSpline

        vertexRotationTime = 0
        vertexRotationIndex = 1

        previousCube = addCube(vertices: cubeVertexOrigins,
                               inScene: scene)

        displaylink = CADisplayLink(target: self,
                                    selector: #selector(vertexRotationStep))

        displaylink?.add(to: .current,
                         forMode: .default)
    }

    @objc
    func vertexRotationStep(displaylink: CADisplayLink) {
        guard isRunning else {
            return
        }

        previousCube?.removeFromParentNode()

        let increment: Float = 0.02
        vertexRotationTime += increment

        let q: simd_quatf
        if vertexRotationUsesSpline {
            q = simd_spline(vertexRotations[vertexRotationIndex - 1],
                            vertexRotations[vertexRotationIndex],
                            vertexRotations[vertexRotationIndex + 1],
                            vertexRotations[vertexRotationIndex + 2],
                            vertexRotationTime)
        } else {
            q = simd_slerp(vertexRotations[vertexRotationIndex],
                           vertexRotations[vertexRotationIndex + 1],
                           vertexRotationTime)
        }

        previousVertexMarker?.removeFromParentNode()
        let vertex = cubeVertices[5]
        cubeVertices = cubeVertexOrigins.map {
            return q.act($0)
        }

        previousVertexMarker = addSphereAt(position: cubeVertices[5],
                                           radius: 0.01,
                                           color: .red,
                                           scene: scene)

        addLineBetweenVertices(vertexA: vertex,
                               vertexB: cubeVertices[5],
                               inScene: scene,
                               color: .white)

        previousCube = addCube(vertices: cubeVertices,
                               inScene: scene)

        if vertexRotationTime >= 1 {
            vertexRotationIndex += 1
            vertexRotationTime = 0

            if vertexRotationIndex > vertexRotations.count - 3 {
                displaylink.invalidate()
                isRunning = false
            }
        }
    }
}
