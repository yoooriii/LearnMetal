//
//  ChartContext_ext.swift
//  MtlTlgChart3
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit
import simd

extension ChartContext {
    
    init(graphRect: float4, screenSize: int2, color: float4, lineWidth:Float, vertexCount:Int, vshaderMode:VShaderMode) {
        self.init()
        self.graphRect = graphRect
        self.screenSize = screenSize
        self.color = color
        self.lineWidth = lineWidth
        self.vertexCount = UInt32(vertexCount)
        self.vshaderMode = vshaderMode.rawValue
    }
    
    static func dashLineContext(graphRect: float4,
                                screenSize: int2,
                                color: float4,
                                lineWidth:Float,
                                lineOffset:float2,
                                lineCount:int2,
                                dashPattern:float2) -> ChartContext
    {
        var instance = ChartContext(graphRect: graphRect, screenSize: screenSize, color: color, lineWidth: lineWidth, vertexCount: 0, vshaderMode: VShaderModeDash)
        instance.extraFloat.0 = dashPattern[0]      // color filled line space
        instance.extraFloat.1 = dashPattern[1]      // empty line space
        instance.extraFloat.2 = lineOffset[0]       // line x offset
        instance.extraFloat.3 = lineOffset[1]       // line y offset
        instance.extraInt.0 = lineCount[0]          // verticalCount
        instance.extraInt.1 = lineCount[1]          // horizontalCount
        return instance
    }

    static func combinedContext(graphRect:float4,
                                screenSize:int2,
                                color: float4,
                                lineWidth:Float,
                                planeCount:Int,
                                planeMask:UInt32,
                                vertexCount:Int,
                                vshaderMode:VShaderMode,
                                arrowPositionX:Float,
                                selectedIndices:(Int, Int)?) -> ChartContext
    {
        // ignore color
        var cx = ChartContext(graphRect: graphRect, screenSize: screenSize,
                        color: color, lineWidth: lineWidth, vertexCount: vertexCount, vshaderMode: vshaderMode)
        cx.extraFloat.0 = arrowPositionX
        cx.extraInt.0 = Int32(planeCount)
        cx.extraInt.1 = Int32(planeMask)
        if let selectedIndices = selectedIndices {
            cx.extraInt.2 = Int32(selectedIndices.0)
            cx.extraInt.3 = Int32(selectedIndices.1)
        } else {
            cx.extraInt.2 = -1
        }
        return cx
    }
}
