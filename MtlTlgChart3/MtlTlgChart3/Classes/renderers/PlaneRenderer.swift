//
//  MetalChartRenderer.swift
//  GraphPresenter
//
//  Created by Andre on 3/27/19.
//  Copyright © 2019 BB. All rights reserved.
//

import Foundation
import MetalKit

class PlaneRenderer: NSObject {
    var alpha: CGFloat = 1.0
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    private let device: MTLDevice!
    // absolute coordinates in graph values
    var graphRect = vector_float4(1)
    // view.drawableSize (no need to keep it here)
    var screenSize = vector_int2(1)
    
    var lineWidth = Float(1)
    private var pointsCount:Int = 0
    private var vertexCount:Int = 0 //{ get { return pointsCount * 2 } }
    private var indexCount:Int = 0
    private var strokeColor:UIColor?
    private var plane:Plane? = nil
    
    //MARK: -

    init(device: MTLDevice!) {
        self.device = device
    }
    
    func setPlane(_ plane:Plane, iPlane:Int) {
        self.plane = plane
        indexCount = 0
        pointsCount = 0
        vertexCount = 0
        if plane.vAmplitudes.count <= iPlane {
            print("wrong graph index \(iPlane)")
            return
        }
        
        pointsCount = min(plane.vTime.count, plane.vAmplitudes[iPlane].count) // the 2 must be equal
        guard pointsCount > 1 else {
            print("too few points in graph (\(pointsCount))")
            graphRect = vector_float4(1)
            return
        }
        guard let device = self.device else {
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
        let minX = Float(plane.vTime.minValue/1000)
        let maxX = Float(plane.vTime.maxValue/1000)
        let minY = Float(plane.vAmplitudes[iPlane].minValue)
        let maxY = Float(plane.vAmplitudes[iPlane].maxValue)
        
        graphRect = vector_float4(minX, minY, maxX, maxY)
        strokeColor = plane.vAmplitudes[iPlane].color

        var arrayIndices = [UInt16]()
        var arrayVertices = [ChartRenderVertex]()
        
        let dx = Float(maxX - minX)/Float(pointsCount * 2)
        // insert a fake point at the beginning
        var vxFirst = ChartRenderVertex(position: points[0])
        vxFirst.position.x -= dx
        arrayVertices.append(vxFirst)
        arrayVertices.append(vxFirst)

        for pt in points {
            let vx = ChartRenderVertex(position: pt)
            arrayVertices.append(vx) // use a point twice
            arrayVertices.append(vx)
        }
        
        // repeat the last point (fake point)
        var vxLast = ChartRenderVertex(position: points[pointsCount - 1])
        vxLast.position.x += dx
        arrayVertices.append(vxLast)
        arrayVertices.append(vxLast)

        //TODO: improvement: index array (buffer) is the same for all graphs
        for idx in stride(from: 0, to: (arrayVertices.count - 3), by: 2) {
            let vertexIndex = UInt16(idx)
            arrayIndices.append(vertexIndex)
            arrayIndices.append(vertexIndex + 2)
            arrayIndices.append(vertexIndex + 3)
            arrayIndices.append(vertexIndex)
            arrayIndices.append(vertexIndex + 3)
            arrayIndices.append(vertexIndex + 1)
        }
        
        // create buffers
        indexCount = arrayIndices.count
        indexBuffer = device.makeBuffer(bytes: arrayIndices,
                                        length: MemoryLayout<UInt16>.stride * indexCount,
                                        options: .cpuCacheModeWriteCombined)
        vertexCount = arrayVertices.count
        vertexBuffer = device.makeBuffer(bytes: arrayVertices,
                                         length: MemoryLayout<ChartRenderVertex>.stride * vertexCount,
                                         options: .cpuCacheModeWriteCombined)
    }
}


extension PlaneRenderer: GraphRenderer {
    // do the work
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        if pointsCount == 0 || indexCount == 0 {
            return
        }
        
        let screenSize = vector_int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        let colorVector = UIColor.vector(strokeColor)
        
        var chartContext = ChartContext(graphRect: graphRect, screenSize: screenSize, color: colorVector, lineWidth:lineWidth, vertexCount:UInt32(vertexCount))
        
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
