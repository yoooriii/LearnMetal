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
    let device: MTLDevice!
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var lineWidth = Float(1)
    // this graphRect can differ from the real graph's graphRect (it makes a scale in shader)
    var graphRect = float4(0)
    var vertexCount:Int = 0
    var indexCount:Int = 0
    var graphMode:VShaderMode = VShaderModeStroke
    var graphPlane:GraphPlaneSlice?
    
    //MARK: -

    init(device: MTLDevice!) {
        self.device = device
    }
    
    func setPlane(_ plane:Plane, iPlane:Int) {
        cleanup()
        guard let _ = self.device else {
            print("no device, won't accept plane")
            return
        }
        graphPlane = GraphPlaneSlice(plane, sliceIndex:iPlane)
        guard let graphPlane = self.graphPlane else {
            return
        }
        graphRect = graphPlane.graphRect

        makeVertexBuffer(graphPlane:graphPlane)
        makeIndexBuffer()
    }
}


private extension GraphRenderer {
    func cleanup() {
        graphPlane = nil
        indexCount = 0
        vertexCount = 0
        vertexBuffer = nil
        indexBuffer = nil
        graphRect = float4(0)
    }
    
    func chartContext(view:MTKView) -> ChartContext! {
        let screenSize = int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        return ChartContext(graphRect: graphRect, screenSize: screenSize, color: graphPlane!.color, lineWidth:lineWidth, vertexCount:UInt32(vertexCount), vshaderMode:Int32(graphMode.rawValue))
    }
    
    func makeVertexBuffer(graphPlane:GraphPlaneSlice) {
        var arrayVertices = [float2]()
        
        let dx = graphPlane.avgDX()/2.0
        // insert a fake point at the beginning
        var vxFirst = graphPlane.firstPoint()
        vxFirst.x -= dx
        arrayVertices.append(vxFirst)
        arrayVertices.append(vxFirst)
        
        for i in 0 ..< graphPlane.pointsCount {
            let vx = graphPlane.point(at: i)
            arrayVertices.append(vx) // use a point twice
            arrayVertices.append(vx)
        }
        
        // repeat the last point (fake point)
        var vxLast = graphPlane.lastPoint()
        vxLast.x += dx
        arrayVertices.append(vxLast)
        arrayVertices.append(vxLast)
        
        vertexCount = arrayVertices.count
        vertexBuffer = device.makeBuffer(bytes: arrayVertices,
                                         length: MemoryLayout<float2>.stride * vertexCount,
                                         options: .cpuCacheModeWriteCombined)
    }

    // create vertex buffer first and only then call this
    func makeIndexBuffer() {
        if vertexCount < 3 {
            print("cannot create index buffer (create vertex buffer first)")
            return
        }
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
    func getOriginalGraphRect() -> float4 {
        if let graphPlane = self.graphPlane {
            return graphPlane.graphRect
        }
        return float4(0)
    }

    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        guard vertexCount != 0, indexCount != 0 else {
            return
        }
        guard let vertexBuffer = self.vertexBuffer, let indexBuffer = self.indexBuffer else {
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
