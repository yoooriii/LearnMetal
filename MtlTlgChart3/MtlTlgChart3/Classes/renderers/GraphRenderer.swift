//
//  MetalChartRenderer.swift
//  GraphPresenter
//
//  Created by Andre on 3/27/19.
//  Copyright © 2019 BB. All rights reserved.
//

import Foundation
import MetalKit

class GraphRenderer: NSObject {
    var alpha: CGFloat = 1.0
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    let device: MTLDevice!
    // absolute coordinates in graph values
    var graphRect = vector_float4(1)
    // view.drawableSize (no need to keep it here)
    var screenSize = vector_int2(1)
    
    var lineWidth = Float(1)
    var pointsCount:Int = 0
    var vertexCount:Int = 0 //{ get { return pointsCount * 2 } }
    var indexCount:Int = 0
    private var strokeColor:UIColor?
    private var plane:Plane? = nil
    private var color:float4 = float4(1)
    var graphMode:VShaderMode = VShaderModeStroke
    
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
        guard let _ = self.device else {
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
        color = UIColor.vector(strokeColor)

        makeVertexBuffer(points: points)
        makeIndexBuffer()
    }
    
    func chartContext(view:MTKView) -> ChartContext! {
        let screenSize = vector_int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        return ChartContext(graphRect: graphRect, screenSize: screenSize, color: color, lineWidth:lineWidth, vertexCount:UInt32(vertexCount), vshaderMode:Int32(graphMode.rawValue))
    }
}


private extension GraphRenderer {
    func makeVertexBuffer(points:[float2]) {
        var arrayVertices = [float2]()
        
        let dx = Float(graphRect[2] - graphRect[0])/Float(pointsCount * 2)
        // insert a fake point at the beginning
        var vxFirst = points[0]
        vxFirst.x -= dx
        arrayVertices.append(vxFirst)
        arrayVertices.append(vxFirst)
        
        for pt in points {
            let vx = pt
            arrayVertices.append(vx) // use a point twice
            arrayVertices.append(vx)
        }
        
        // repeat the last point (fake point)
        var vxLast = points[pointsCount - 1]
        vxLast.x += dx
        arrayVertices.append(vxLast)
        arrayVertices.append(vxLast)
        
        vertexCount = arrayVertices.count
        vertexBuffer = device.makeBuffer(bytes: arrayVertices,
                                         length: MemoryLayout<float2>.stride * vertexCount,
                                         options: .cpuCacheModeWriteCombined)
    }
    
    func makeIndexBuffer() {
        var arrayIndices = [UInt16]()
        //TODO: improvement: index array (buffer) is the same for all graphs
        for idx in stride(from: 0, to: (vertexCount - 3), by: 2) {
            let vertexIndex = UInt16(idx)
            arrayIndices.append(vertexIndex)
            arrayIndices.append(vertexIndex + 2)
            arrayIndices.append(vertexIndex + 3)
            arrayIndices.append(vertexIndex)
            arrayIndices.append(vertexIndex + 3)
            arrayIndices.append(vertexIndex + 1)
        }
        
        indexCount = arrayIndices.count
        indexBuffer = device.makeBuffer(bytes: arrayIndices,
                                        length: MemoryLayout<UInt16>.stride * indexCount,
                                        options: .cpuCacheModeWriteCombined)
    }
}


extension GraphRenderer: GraphRendererProto {
    @objc func loadResources() {}
    
    // do the work
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        if pointsCount == 0 || indexCount == 0 {
            return
        }
        
        var chartCx = chartContext(view:view)
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0,
                                index: Int(AAPLVertexInputIndexVertices.rawValue))
        encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                               index: Int(AAPLVertexInputIndexChartContext.rawValue))
        
        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: indexCount,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset:0)
    }
}
