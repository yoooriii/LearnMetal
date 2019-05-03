//
//  GridRenderer.swift
//  MtlTlgChart3
//
//  Created by Leonid Lokhmatov on 4/24/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

class GridRenderer: NSObject {
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
    
    private var pointerVertices: [float2]?
    
    //MARK: -
    
    init(device: MTLDevice!) {
        self.device = device
        
    }
    
    func loadResources() {
        let pointRect = CGRect(x: -10, y: -10, width: 20, height: 20)
        pointerVertices = makeTestCircularVertices(rect: pointRect, steps: 12)
    }
    

}

private extension GridRenderer {
    func makeTestCircularVertices(rect: CGRect, steps:Int) -> [float2] {
        var resVertices = [float2]()
        if steps < 3 {
            print("too few steps \(steps)")
            return resVertices
        }
        
        let maxR = Float(min(rect.width, rect.height) * 0.4)
        let minR = maxR / 2.0
        let origin = float2(Float(rect.minX), Float(rect.minY))
        let pi2 = Float.pi * 2.0
        
        for i in 0 ..< steps * 2 {
            let a = pi2 * Float(i) / Float(steps * 2)
            let r = (i & 1 == 0) ? maxR : minR
            let pos = float2(sin(a), cos(a)) * r + origin
            resVertices.append(pos)
        }
        
        return resVertices
    }
}

extension GridRenderer: GraphRendererProto {
    func getOriginalGraphRect() -> float4 {
        // it is wrong?
        return graphRect
    }
    
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        if pointsCount == 0 || indexCount == 0 {
            return
        }
        
        let screenSize = vector_int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        let colorVector = UIColor.vector(strokeColor)
        
        var chartContext = ChartContext(graphRect: graphRect, screenSize: screenSize, color: colorVector, lineWidth:lineWidth, vertexCount:UInt32(vertexCount), vshaderMode:Int32(VShaderModeFill.rawValue))
        
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
