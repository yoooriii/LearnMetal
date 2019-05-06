//
//  GridRenderer.swift
//  MtlTlgChart3
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit
import MetalKit

class GridRenderer: NSObject {
    private let device: MTLDevice!
    // fake vertex coordinates, the vertex shader just ignores them
    private let vertexArray = [Float](repeating: Float(0), count: 4)
    var graphMode:VShaderMode = VShaderModeStroke
    let lineCount = uint2(10, 11) // horizontal/vertical lines count
    // absolute coordinates in graph values
    var graphRect = float4(0)
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
    
    func setViewSize(viewSize:uint2) {
        graphRect = float4(0,0, Float(viewSize[0]), Float(viewSize[1])) // should we change it here and this way?
    }
}

private extension GridRenderer {
    func chartContext(view:MTKView) -> ChartContext! {
        let screenSize = int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        return ChartContext.dashLineContext(graphRect: graphRect, screenSize: screenSize, color: strokeColor, lineWidth: lineWidth, lineOffset: gridCellSize, lineCount: lineCount, dashPattern: lineDashPattern)
    }
}

extension GridRenderer: GraphRendererProto {
    func getOriginalGraphRect() -> float4 {
        return graphRect
    }
    
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        guard vertexArray.count != 0 else {
            return
        }
        // the draw logic is as simple as this: write 4 vertices for every line,
        // then the vertex shader will calculate the real vertex coordinates
        // using ChartContext properties (the current vertex values are to ignore)
        var chartCx = chartContext(view:view)
        encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                               index: Int(AAPLVertexInputIndexChartContext.rawValue))
        encoder.setVertexBytes(vertexArray, length: MemoryLayout<Float>.stride * vertexArray.count, index: Int(AAPLVertexInputIndexVertices.rawValue))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: Int(lineCount[0] + lineCount[1]))
    }
}
