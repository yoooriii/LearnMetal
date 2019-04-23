/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Class containing methods for SceneKit scene rendering.
*/

import UIKit
import simd
import SceneKit

extension ViewController {
    func degreesToRadians(_ degrees: Float) -> Float {
        return degrees * .pi / 180
    }

    func setupSceneKit(shadows: Bool = true) -> SCNScene {
        sceneKitView.allowsCameraControl = false

        let scene = SCNScene()
        sceneKitView.scene = scene

        scene.background.contents = UIColor(red: 41 / 255,
                                            green: 42 / 255,
                                            blue: 48 / 255,
                                            alpha: 1)

        let lookAtNode = SCNNode()

        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.name = "cameraNode"
        cameraNode.camera = camera
        camera.fieldOfView = 25
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1.5
        cameraNode.position = SCNVector3(x: 2.5, y: 2.0, z: 5.0)
        let lookAt = SCNLookAtConstraint(target: lookAtNode)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [ lookAt ]

        let light = SCNLight()
        light.type = .omni
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(x: -1.5, y: 2.5, z: 1.5)

        if shadows {
            light.type = .directional
            light.castsShadow = true
            light.shadowSampleCount = 8
            lightNode.constraints = [ lookAt ]
        }

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: 0.5, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient

        scene.rootNode.addChildNode(lightNode)
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(ambientNode)

        addAxisArrows(scene: scene)

        return scene
    }

    func addLineBetweenVertices(vertexA: simd_float3,
                                vertexB: simd_float3,
                                inScene scene: SCNScene,
                                useSpheres: Bool = false,
                                color: UIColor = .yellow) {
        if useSpheres {
            addSphereAt(position: vertexB,
                        radius: 0.01,
                        color: .red,
                        scene: scene)
        } else {
            let geometrySource = SCNGeometrySource(vertices: [SCNVector3(x: vertexA.x,
                                                                         y: vertexA.y,
                                                                         z: vertexA.z),
                                                              SCNVector3(x: vertexB.x,
                                                                         y: vertexB.y,
                                                                         z: vertexB.z)])
            let indices: [Int8] = [0, 1]
            let indexData = Data(bytes: indices, count: 2)
            let element = SCNGeometryElement(data: indexData,
                                             primitiveType: .line,
                                             primitiveCount: 1,
                                             bytesPerIndex: MemoryLayout<Int8>.size)

            let geometry = SCNGeometry(sources: [geometrySource],
                                       elements: [element])

            geometry.firstMaterial?.isDoubleSided = true
            geometry.firstMaterial?.emission.contents = color

            let node = SCNNode(geometry: geometry)

            scene.rootNode.addChildNode(node)
        }
    }

    @discardableResult
    func addTriangle(vertices: [simd_float3], inScene scene: SCNScene) -> SCNNode {
        assert(vertices.count == 3, "vertices count must be 3")

        let vector1 = vertices[2] - vertices[1]
        let vector2 = vertices[0] - vertices[1]
        let normal = simd_normalize(simd_cross(vector1, vector2))

        let normalSource = SCNGeometrySource(normals: [SCNVector3(x: normal.x, y: normal.y, z: normal.z),
                                                       SCNVector3(x: normal.x, y: normal.y, z: normal.z),
                                                       SCNVector3(x: normal.x, y: normal.y, z: normal.z)])

        let sceneKitVertices = vertices.map {
            return SCNVector3(x: $0.x, y: $0.y, z: $0.z)
        }
        let geometrySource = SCNGeometrySource(vertices: sceneKitVertices)

        let indices: [Int8] = [0, 1, 2]
        let indexData = Data(bytes: indices, count: 3)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangles,
                                         primitiveCount: 1,
                                         bytesPerIndex: MemoryLayout<Int8>.size)

        let geometry = SCNGeometry(sources: [geometrySource, normalSource],
                                   elements: [element])

        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.diffuse.contents = UIColor.orange

        let node = SCNNode(geometry: geometry)

        scene.rootNode.addChildNode(node)

        return node
    }

    func addCube(vertices: [simd_float3], inScene scene: SCNScene) -> SCNNode {
        assert(vertices.count == 8, "vertices count must be 3")

        let sceneKitVertices = vertices.map {
            return SCNVector3(x: $0.x, y: $0.y, z: $0.z)
        }
        let geometrySource = SCNGeometrySource(vertices: sceneKitVertices)

        let indices: [Int8] = [
            // bottom
            0, 2, 1,
            1, 2, 3,
            // back
            2, 6, 3,
            3, 6, 7,
            // left
            0, 4, 2,
            2, 4, 6,
            // right
            1, 3, 5,
            3, 7, 5,
            // front
            0, 1, 4,
            1, 5, 4,
            // top
            4, 5, 6,
            5, 7, 6 ]

        let indexData = Data(bytes: indices, count: indices.count)
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .triangles,
                                         primitiveCount: 12,
                                         bytesPerIndex: MemoryLayout<Int8>.size)

        let geometry = SCNGeometry(sources: [geometrySource],
                                   elements: [element])

        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.diffuse.contents = UIColor.purple
        geometry.firstMaterial?.lightingModel = .physicallyBased

        let node = SCNNode(geometry: geometry)

        scene.rootNode.addChildNode(node)

        return node
    }

    func addAxisArrows(scene: SCNScene) {
        let xArrow = arrow(color: UIColor.red)
        xArrow.simdEulerAngles = simd_float3(x: 0, y: 0, z: -.pi * 0.5)

        let yArrow = arrow(color: UIColor.green)

        let zArrow = arrow(color: UIColor.blue)
        zArrow.simdEulerAngles = simd_float3(x: .pi * 0.5, y: 0, z: 0)

        let node = SCNNode()
        node.addChildNode(xArrow)
        node.addChildNode(yArrow)
        node.addChildNode(zArrow)

        node.simdPosition = simd_float3(x: -1.5, y: -1.25, z: 0.0)

        scene.rootNode.addChildNode(node)
    }

    func arrow(color: UIColor) -> SCNNode {
        let cylinder = SCNCylinder(radius: 0.01, height: 0.5)
        cylinder.firstMaterial?.diffuse.contents = color
        let cylinderNode = SCNNode(geometry: cylinder)

        let cone = SCNCone(topRadius: 0, bottomRadius: 0.03, height: 0.1)
        cone.firstMaterial?.diffuse.contents = color
        let coneNode = SCNNode(geometry: cone)

        coneNode.simdPosition = simd_float3(x: 0, y: 0.25, z: 0)

        let returnNode = SCNNode()
        returnNode.addChildNode(cylinderNode)
        returnNode.addChildNode(coneNode)

        returnNode.pivot = SCNMatrix4MakeTranslation(0, -0.25, 0)

        return returnNode
    }

    @discardableResult
    func addSphereAt(position: simd_float3, radius: CGFloat = 0.1, color: UIColor, scene: SCNScene) -> SCNNode {
        let sphere = SCNSphere(radius: radius)
        sphere.firstMaterial?.diffuse.contents = color
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.simdPosition = position
        scene.rootNode.addChildNode(sphereNode)

        return sphereNode
    }

    func addMainSphere(scene: SCNScene) {
        let sphereRotation = simd_float3(x: degreesToRadians(0), y: 0, z: 0) // was 30
        let sphere = SCNSphere(radius: 1)
        sphere.firstMaterial?.transparency = 0.85
        sphere.firstMaterial?.locksAmbientWithDiffuse = true
        sphere.firstMaterial?.diffuse.contents = UIColor(red: 0.75, green: 0.5, blue: 0.5, alpha: 1)
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.simdEulerAngles = sphereRotation
        scene.rootNode.addChildNode(sphereNode)
        let wireFrameSphere = SCNSphere(radius: 1)
        wireFrameSphere.firstMaterial?.fillMode = .lines
        wireFrameSphere.firstMaterial?.shininess = 1
        wireFrameSphere.firstMaterial?.diffuse.contents = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        let wireFrameSphereNode = SCNNode(geometry: wireFrameSphere)
        wireFrameSphereNode.simdEulerAngles = sphereRotation
        scene.rootNode.addChildNode(wireFrameSphereNode)
    }
}
