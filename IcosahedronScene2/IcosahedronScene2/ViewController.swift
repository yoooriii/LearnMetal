//
//  ViewController.swift
//  IcosahedronScene2
//
//  Created by Leonid Lokhmatov on 4/17/19.
//  Copyright © 2018 Luxoft. All rights reserved
//
//  https://www.invasivecode.com/weblog/scenekit-tutorial-part-2/

import UIKit
import SceneKit

class ViewController: UIViewController {
    @IBOutlet var sceneView: SCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = SCNScene()
        
        // set the scene to the view
        sceneView.scene = scene
        
        // allows the user to manipulate the camera
        sceneView.allowsCameraControl = true
        // show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        let icosahedron = generateIcosahedron()
        let icosahedronNode = SCNNode(geometry: icosahedron)
        scene.rootNode.addChildNode(icosahedronNode)
        
        sceneView.delegate = self
    }
    
    private func generateIcosahedron() -> SCNGeometry {
        
        let t = (1.0 + sqrt(5.0)) / 2.0;
        
        let vertices: [SCNVector3] = [
            SCNVector3(-1,  t, 0), SCNVector3( 1,  t, 0), SCNVector3(-1, -t, 0), SCNVector3( 1, -t, 0),
            SCNVector3(0, -1,  t), SCNVector3(0,  1,  t), SCNVector3(0, -1, -t), SCNVector3(0,  1, -t),
            SCNVector3( t,  0, -1), SCNVector3( t,  0,  1), SCNVector3(-t,  0, -1), SCNVector3(-t,  0,  1) ]
        
        
        let data = NSData(bytes: vertices, length: MemoryLayout<SCNVector3>.size * vertices.count) as Data
        
        let vertexSource = SCNGeometrySource(data: data,
                                             semantic: .vertex,
                                             vectorCount: vertices.count,
                                             usesFloatComponents: true,
                                             componentsPerVector: 3,
                                             bytesPerComponent: MemoryLayout<Float>.size,
                                             dataOffset: 0,
                                             dataStride: MemoryLayout<SCNVector3>.stride)
        
        let indices: [Int32] = [
            0, 5, 1, 0, 1, 5, 1, 7, 1, 8, 1, 9, 2, 3, 2, 4, 2, 6, 2, 10, 2, 11, 3, 6, 3, 8, 3, 9, 4, 3, 4, 5,
            4, 9, 5, 9, 6, 7, 6, 8, 6, 10, 9, 8, 8, 7, 7, 0, 10, 0, 10, 7, 10, 11, 11, 0, 11, 4, 11, 5 ]
        
        let indexData = NSData(bytes: indices, length: MemoryLayout<Int32>.size * indices.count) as Data
        
        let element = SCNGeometryElement(data: indexData,
                                         primitiveType: .line,
                                         primitiveCount: indices.count/2,
                                         bytesPerIndex: MemoryLayout<Int32>.size)
        
        
        ////// Add random colors
        var vertexColors = [SCNVector3]()
        
        for _ in 0..<vertices.count {
            let red = Float(arc4random() % 255) / 255.0
            let green = Float(arc4random() % 255) / 255.0
            let blue = Float(arc4random() % 255) / 255.0
            vertexColors.append(SCNVector3(red, green, blue))
        }
        
        
        let dataColor = NSData(bytes: vertexColors, length: MemoryLayout<SCNVector3>.size * vertices.count) as Data
        
        let colors = SCNGeometrySource(data: dataColor,
                                       semantic: .color,
                                       vectorCount: vertexColors.count,
                                       usesFloatComponents: true,
                                       componentsPerVector: 3,
                                       bytesPerComponent: MemoryLayout<Float>.size,
                                       dataOffset: 0,
                                       dataStride: MemoryLayout<SCNVector3>.stride)
        
        return SCNGeometry(sources: [vertexSource, colors], elements: [element])
    }
}

extension ViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // this works in case renderingAPI = .openGLES2 (set it in IB)
        glLineWidth(10)
    }
}
