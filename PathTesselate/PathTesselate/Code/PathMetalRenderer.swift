//
//  PathMetalRenderer.swift
//  PathTesselate
//
//  Created by Leonid Lokhmatov on 4/22/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

class PathMetalRenderer: NSObject, BasicDrawMetalProto {
    private let device: MTLDevice!
    // The current size of our view so we can use this in our render pipeline
    private var viewportSize: vector_uint2 = vector_uint2(0)

    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var indexCount = 0
    private var vertexCount = 0
    
    private var path:CGPath?
    
    init(device:MTLDevice!) {
        self.device = device
    }
    
    func runTest() {
        if let device = self.device {
            makeDebugData3(device: device)
        } else {
            print("no device, no test")
        }
    }
    
    func setPath(_ path: CGPath) {
        self.path = path
        
        guard let device = self.device else {
            print("no device")
            return
        }
        
        let contour = ContourHandler()
        contour.debugLevel = 1
        contour.evaluatePath(path)
        print("evaluated \(contour.count) points")
        if let buffers = contour.createMesh(with:device) {
            vertexBuffer = buffers.vertexBuffer
            vertexCount = Int(buffers.vertexCount)
            indexCount = Int(buffers.indexCount)
            indexBuffer = buffers.indexBuffer
        }
    }
    
    private func makeDebugData3(device:MTLDevice!) {
        let rect = CGRect(x: 50, y: 50, width: 600, height: 200)
        let bbb = TestPathMath.createTestPath(in: rect)
        let path = bbb.takeRetainedValue()//CGPath(ellipseIn: rect, transform: nil)
//        let path = CGPath(rect: rect, transform: nil)
        let lw = CGFloat(50.0)
        let path2 = path.copy(strokingWithWidth: lw, lineCap: .round, lineJoin: .round, miterLimit: lw)
        
        let contour = ContourHandler()
        contour.debugLevel = 1
        contour.evaluatePath(path2)
        print("evaluated \(contour.count) points")
        if let buffers = contour.createMesh(with:device)
        {
            vertexBuffer = buffers.vertexBuffer
            vertexCount = Int(buffers.vertexCount)
            indexCount = Int(buffers.indexCount)
            indexBuffer = buffers.indexBuffer
        }
    }
    
    
    private func makeDebugData1(device:MTLDevice!) {
        let vertices:[TestVertex] = [TestVertex(x:20, y:20), TestVertex(x:220, y:120), TestVertex(x:20, y:120), TestVertex(x:220, y:20)]
        let indices:[UInt16] = [0,1,2,  0,1,3]
        
        indexCount = indices.count
        vertexCount = vertices.count
        
        let sizeVertices = MemoryLayout<TestVertex>.stride * vertexCount
        vertexBuffer = device.makeBuffer(bytes: vertices, length: sizeVertices, options:.cpuCacheModeWriteCombined)
        
        let sizeIndices = MemoryLayout<UInt16>.stride * indexCount
        indexBuffer = device.makeBuffer(bytes: indices, length: sizeIndices, options: .cpuCacheModeWriteCombined)
        
        
        guard let vertexMemArray = vertexBuffer?.contents().bindMemory(to: TestVertex.self, capacity: vertexCount) else {
            print("no vertex array")
            return
        }
        
        guard let indexMemArray = indexBuffer?.contents().bindMemory(to: UInt16.self, capacity: indexCount) else {
            print("no index array")
            return
        }
        
        for i in 0 ..< vertexCount {
            vertexMemArray[i] = vertices[i]
        }
        
        for i in 0 ..< indexCount {
            indexMemArray[i] = indices[i]
        }
    }

    func fillEncoder(_ encoder:MTLRenderCommandEncoder, mtkView:MTKView) {
        guard let indexBuffer = self.indexBuffer,
            let vertexBuffer = self.vertexBuffer else {
                return
        }
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(AAPLVertexInputIndexVertices.rawValue))
        
        let strokeColor = vector_float4(0.5, 0.1, 0.1, 1.0)
        let fillColor = vector_float4(0.0, 1.0, 0.0, 1.0)
        var renderCx = AAPLRenderContext(strokeColor: strokeColor, fillColor: fillColor, viewportSize:viewportSize)
        encoder.setVertexBytes(&renderCx,
                               length: MemoryLayout<AAPLRenderContext>.stride,
                               index: Int(AAPLVertexInputIndexRenderContext.rawValue))
        
        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: indexCount,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset:0)
        
        renderCx.strokeColor = vector_float4(1.0, 1.0, 1.0, 1.0)
        encoder.setVertexBytes(&renderCx,
                               length: MemoryLayout<AAPLRenderContext>.stride,
                               index: Int(AAPLVertexInputIndexRenderContext.rawValue))
        
        return
        
        let drawIndexSceleton = true
        if drawIndexSceleton {
            encoder.drawIndexedPrimitives(type: .lineStrip,
                                          indexCount: indexCount,
                                          indexType: .uint16,
                                          indexBuffer: indexBuffer,
                                          indexBufferOffset:0)
        } else {
            encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertexCount)
        }
    }
    
    func makeViewport() -> MTLViewport? {
        // Set the region of the drawable to which we'll draw.
        let viewport = MTLViewport(originX:0, originY:0,
                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
                                   znear: -1.0, zfar: 1.0)
        return viewport
    }
    
    func drawableSizeWillChange(_ size: CGSize) {
        viewportSize.x = UInt32(size.width)
        viewportSize.y = UInt32(size.height)
    }
}
