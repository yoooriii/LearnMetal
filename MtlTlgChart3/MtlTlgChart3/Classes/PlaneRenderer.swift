//
//  MetalChartRenderer.swift
//  GraphPresenter
//
//  Created by Andre on 3/27/19.
//  Copyright © 2019 BB. All rights reserved.
//

import Foundation
import MetalKit

// : IMetalSurfaceRenderer
class PlaneRenderer: NSObject {
    var alpha: CGFloat = 1.0
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    
    /////////////
    let device: MTLDevice!
    // absolute coordinates in graph values
    var viewportSize = vector_int4(1)
    // view.drawableSize (no need to keep it here)
    var screenSize = vector_int2(1)
    
    var pointsCount = 0
    var vertexCount:Int { get { return pointsCount * 2 } }
    var strokeColor:UIColor?
    var lineWidth = Float(10)//Float(1.5)

    /// Initialize with the MetalKit view from which we'll obtain our Metal device
    init(device: MTLDevice!) {
        self.device = device
    }
    
    private var plane:Plane? = nil
    
    func setPlane(_ plane:Plane, iPlane:Int) {
        self.plane = plane

        if plane.vAmplitudes.count <= iPlane {
            print("wrong plane index \(iPlane)")
            return
        }

        let count1 = plane.vTime.count
        let countP = plane.vAmplitudes.count
        let count2 = plane.vAmplitudes[iPlane].count
        print("set new plane with \(countP) amplitudes and [\(count1):\(count2)] points")
        
        pointsCount = min(count1, count2)
        guard pointsCount > 1 else {
            print("too few points in graph (\(pointsCount))")
            pointsCount = 0
            viewportSize = vector_int4(1)
            return
        }

        // next create buffers and start drawing
        guard let device = self.device else {
            return
        }


        let vertexMemSize = MemoryLayout<ChartRenderVertex>.stride * pointsCount * 2
        let totalIndexCount = pointsCount * 6 // not exactly
        let indexMemSize = MemoryLayout<UInt16>.stride * pointsCount * 6
        indexBuffer = device.makeBuffer(length: indexMemSize, options: .cpuCacheModeWriteCombined)
        vertexBuffer = device.makeBuffer(length: vertexMemSize, options: .cpuCacheModeWriteCombined)
        
        guard let vertexMemArray = vertexBuffer?.contents().bindMemory(to: ChartRenderVertex.self, capacity: pointsCount) else {
            print("no vertex array")
            return
        }
        
        guard let indexMemArray = indexBuffer?.contents().bindMemory(to: UInt16.self, capacity: totalIndexCount) else {
            print("no index array")
            return
        }
        
        //TODO: double conversion: repack coordinates
        var points = [float2]()
        for i in 0 ..< pointsCount {
            let x = plane.vTime.values[i]/1000
            let y = plane.vAmplitudes[iPlane].values[i]
            let p = float2(Float(x), Float(y))
            points.append(p)
        }
        let minX = Int32(plane.vTime.minValue/1000)
        let maxX = Int32(plane.vTime.maxValue/1000)
        let minY = Int32(plane.vAmplitudes[iPlane].minValue)
        let maxY = Int32(plane.vAmplitudes[iPlane].maxValue)
        viewportSize = vector_int4(minX, minY, maxX, maxY)
        strokeColor = plane.vAmplitudes[iPlane].color

        for iPoint in 0 ..< pointsCount {
            let vx = ChartRenderVertex(position: points[iPoint])
            vertexMemArray[iPoint * 2] = vx
            vertexMemArray[iPoint * 2 + 1] = vx

            let isLast = iPoint >= pointsCount - 1
            if !isLast {
                let ibi = iPoint * 6
                let vertexIndex = UInt16(iPoint * 2)
                indexMemArray[ibi]   = vertexIndex
                indexMemArray[ibi+1] = vertexIndex + 2
                indexMemArray[ibi+2] = vertexIndex + 3
                indexMemArray[ibi+3] = vertexIndex
                indexMemArray[ibi+4] = vertexIndex + 3
                indexMemArray[ibi+5] = vertexIndex + 1
            }
        }
    }


}

extension PlaneRenderer {

    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        let viewSize = view.drawableSize
        let screenSize = vector_int2(Int32(viewSize.width), Int32(viewSize.height))
        let indexCount = (pointsCount - 1) * 6;
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        let colorVector = UIColor.vector(strokeColor)

        var chartContext = ChartContext(viewportSize: viewportSize, screenSize: screenSize, color: colorVector, lineWidth:lineWidth, vertexCount:UInt32(vertexCount))

        encoder.setVertexBuffer(vertexBuffer, offset: 0,
                                index: Int(AAPLVertexInputIndexVertices.rawValue))
        encoder.setVertexBytes(&chartContext, length: MemoryLayout<ChartContext>.stride,
                               index: Int(AAPLVertexInputIndexChartContext.rawValue))

        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: indexCount,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset:0)
    }
}
