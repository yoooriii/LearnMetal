//
//  LineDescriptor.swift
//  MtlTlgChart4
//
//  Created by leonid@leeloo on 5/24/19 ©2019 Horns&Hoofs.®
//

import Foundation

extension LineDescriptor {
    static func vertical(color:float4, dashPattern:float2, lineWidth: Float, offset: Float) -> LineDescriptor {
        return LineDescriptor(color: color, isVertical: Int32(1), dashPattern: dashPattern, lineWidth: lineWidth, offset: offset)
    }

    static func horizontal(color:float4, dashPattern:float2, lineWidth: Float, offset: Float) -> LineDescriptor {
        return LineDescriptor(color: color, isVertical: Int32(0), dashPattern: dashPattern, lineWidth: lineWidth, offset: offset)
    }
}

typealias ElementInt = (Int)
extension Array where Iterator.Element == ElementInt {
    func _safeValue(at index:Int) -> Int {
        return index >= self.count ? 0 : self[index]
    }
}

class DrawDescriptors {
    static func verticalLineDescriptor(color:float4, dashPattern:float2, lineWidth:Float, indices:[Int]) -> VerticalLineDescriptor {
        return VerticalLineDescriptor(color:color,
                                      dashPattern:dashPattern,
                                      lineWidth:lineWidth,
                                      count:uint(min(indices.count, 20)),
                                      vxIndices: (
            UInt32(indices._safeValue(at:0)),
            UInt32(indices._safeValue(at:1)),
            UInt32(indices._safeValue(at:2)),
            UInt32(indices._safeValue(at:3)),
            UInt32(indices._safeValue(at:4)),
            UInt32(indices._safeValue(at:5)),
            UInt32(indices._safeValue(at:6)),
            UInt32(indices._safeValue(at:7)),
            UInt32(indices._safeValue(at:8)),
            UInt32(indices._safeValue(at:9)),
            UInt32(indices._safeValue(at:10)),
            UInt32(indices._safeValue(at:11)),
            UInt32(indices._safeValue(at:12)),
            UInt32(indices._safeValue(at:13)),
            UInt32(indices._safeValue(at:14)),
            UInt32(indices._safeValue(at:15)),
            UInt32(indices._safeValue(at:16)),
            UInt32(indices._safeValue(at:17)),
            UInt32(indices._safeValue(at:18)),
            UInt32(indices._safeValue(at:19)))   )
    }
}
