//
//  ZGraphOverlayRenderer
//  MtlTlgChart3
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit
import MetalKit

class ZGraphOverlayRenderer: NSObject {
    let graphMode = VShaderModeStroke
    let lineCount = int2(10, 11) // horizontal/vertical lines count
    // absolute coordinates in graph values
    var graphRect = float4(0)
    // grid properties
    var strokeColor = float4(0.5, 0.5, 0.5, 1.0)
    var lineWidth = Float(1)
    var lineDashPattern:float2 = float2(5,15)
    var gridCellSize:float2 = float2(100,100)
    var gridMaxSize:float2 = float2(1000,1000)
    
    //MARK: -
    
    func setViewSize(viewSize:int2) {
        graphRect = float4(0,0, Float(viewSize[0]), Float(viewSize[1])) // should we change it here and this way?
    }
    
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        // the draw logic is as simple as this: write fake data for every line,
        // then the vertex shader calculates the real vertex coordinates
        // using ChartContext properties
        var chartCx = chartContext(view:view)
        encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                               index: Int(ZVxShaderBidChartContext.rawValue))
        let fakeVertex = [float4(0)]  // any data will do, the shader does not use it
        encoder.setVertexBytes(fakeVertex, length: MemoryLayout<Float>.stride * 4, index: Int(ZVxShaderBidVertices.rawValue))
        encoder.setVertexBytes([float4(0)], length: MemoryLayout<float4>.stride, // we dont use colors
            index: Int(ZVxShaderBidColor.rawValue))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: Int(lineCount[0] + lineCount[1]))
    }
}

private extension ZGraphOverlayRenderer {
    func chartContext(view:MTKView) -> ChartContext! {
        let screenSize = int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        return ChartContext.dashLineContext(graphRect: graphRect, screenSize: screenSize, color: strokeColor, lineWidth: lineWidth, lineOffset: gridCellSize, lineCount: lineCount, dashPattern: lineDashPattern)
    }
}
