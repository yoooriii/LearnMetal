//
//  ChartContext_ext.swift
//  MtlTlgChart3
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit
import simd

//vector_float4 visibleRect;//graphRect;
//vector_float4 boundingBox;

struct ArrowPointer {
    var radius1: Float
    var radius2: Float
    var offsetNX: Float
    var range: NSRange?
    
    init(radius:Float, offsetNX:Float, range:NSRange?) {
        self.radius1 = radius/2.0
        self.radius2 = radius
        self.offsetNX = offsetNX
        self.range = range
    }
}

extension ChartContext {
    
    init(visibleRect: float4,
         boundingBox: float4,
         screenSize: int2,
         lineWidth:Float,
         vertexCount:Int,
         vshaderMode:VShaderMode,
         arrowPointer:ArrowPointer?)
    {
        self.init()
        self.visibleRect = visibleRect
        self.boundingBox = boundingBox
        self.screenSize = screenSize
        self.lineWidth = lineWidth
        self.vertexCount = UInt32(vertexCount)
        self.vshaderMode = vshaderMode.rawValue
        if let arrowPointer = arrowPointer {
            self.ptRadius1 = arrowPointer.radius1
            self.ptRadius2 = arrowPointer.radius2
            self.ptOffsetNX = arrowPointer.offsetNX
            let range = arrowPointer.range ?? NSMakeRange(-1, -1)
            self.ptRange = int2(Int32(range.location), Int32(range.length))
        } else {
            self.ptRadius1 = 0
            self.ptRadius2 = 0
            self.ptOffsetNX = -1
            self.ptRange = int2(-1)
        }
    }
    
    static func dashLineContext(visibleRect: float4,
                                boundingBox: float4,
                                screenSize: int2,
                                lineWidth:Float,
                                lineOffset:float2,
                                lineCount:int2,
                                dashPattern:float2) -> ChartContext
    {
        var instance = ChartContext(visibleRect: visibleRect,
                                    boundingBox: boundingBox,
                                    screenSize: screenSize,
                                    lineWidth: lineWidth,
                                    vertexCount: 0,
                                    vshaderMode: VShaderModeDash,
                                    arrowPointer:nil)
        instance.extraFloat.0 = dashPattern[0]      // color filled line space
        instance.extraFloat.1 = dashPattern[1]      // empty line space
        instance.extraFloat.2 = lineOffset[0]       // line x offset
        instance.extraFloat.3 = lineOffset[1]       // line y offset
        instance.extraInt.0 = lineCount[0]          // verticalCount
        instance.extraInt.1 = lineCount[1]          // horizontalCount
        return instance
    }

    mutating func setMode(_ mode: VShaderMode) {
        vshaderMode = mode.rawValue
    }
}
