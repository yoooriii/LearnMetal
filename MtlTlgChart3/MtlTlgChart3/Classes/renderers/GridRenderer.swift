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
    private let device: MTLDevice!
    private let vertexArray = [float2](repeating: float2(0), count: 4)
    var graphMode:VShaderMode = VShaderModeStroke
    
    let lineCount = uint2(10, 11) // horizontal/vertical lines count


    // absolute coordinates in graph values
    var graphRect = float4(0) {
        didSet{
            print("GridRenderer:graphRect:didSet: \(graphRect)")
        }
    }

    // grid properties
    var strokeColor = float4(0.5, 0.5, 0.5, 1.0)
    var lineWidth = Float(1)
    var lineDashPattern:float2 = float2(5,15)
    var gridCellSize:float2 = float2(100,100)
    var gridMaxSize:float2 = float2(1000,1000)
    
    
    //MARK: -
    
    init(device: MTLDevice!) {
        self.device = device
        
    }
    
    func loadContent(viewSize:uint2) {
        graphRect = float4(0,0, Float(viewSize[0]), Float(viewSize[1])) // should we change it here and this way?
    }
}

private extension GridRenderer {
    //debug method
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

    func chartContext(view:MTKView) -> ChartContext! {
        let screenSize = int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        return ChartContext.dashLineContext(graphRect: graphRect, screenSize: screenSize, color: strokeColor, lineWidth: lineWidth, lineOffset: gridCellSize, lineCount: lineCount, dashPattern: lineDashPattern)
    }
}

extension GridRenderer: GraphRendererProto {
    func getOriginalGraphRect() -> float4 {
        // it is wrong?
        return graphRect
    }
    
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        guard vertexArray.count != 0 else {
            return
        }
        
        var chartCx = chartContext(view:view)
        encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                               index: Int(AAPLVertexInputIndexChartContext.rawValue))
        encoder.setVertexBytes(vertexArray, length: MemoryLayout<float2>.stride * vertexArray.count, index: Int(AAPLVertexInputIndexVertices.rawValue))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: Int(lineCount[0] + lineCount[1]))
    }
}
