//
//  GraphPlaneSlice.swift
//  MtlTlgChart3
//
//  Created by Leonid Lokhmatov on 5/3/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import Foundation
import simd

class GraphPlaneSlice {
    let plane:Plane!
    let sliceIndex:Int!
    let pointsCount:Int!
    let graphRect:float4!
    let color:float4!
    let TimeScale = Int64(1000) // ms -> sec (1 sec = 1000 ms)
    
    init?(_ plane:Plane, sliceIndex:Int) {
        if plane.vAmplitudes.count <= sliceIndex {
            print("wrong graph index \(sliceIndex)")
            return nil
        }
        
        let pointsCount = min(plane.vTime.count, plane.vAmplitudes[sliceIndex].count) // the 2 must be equal
        guard pointsCount > 1 else {
            print("too few points in graph (\(pointsCount))")
            return nil
        }
        self.pointsCount = pointsCount
        
        graphRect = float4(Float(plane.vTime.minValue/TimeScale),
                           Float(plane.vAmplitudes[sliceIndex].minValue),
                           Float(plane.vTime.maxValue/TimeScale),
                           Float(plane.vAmplitudes[sliceIndex].maxValue))
        
        color = plane.vAmplitudes[sliceIndex].colorVector
        
        self.plane = plane
        self.sliceIndex = sliceIndex
    }
    
    func firstPoint() -> float2 {
        return point(at: 0)
    }
    
    func lastPoint() -> float2 {
        return point(at: pointsCount-1)
    }
    
    func point(at idx:Int) -> float2 {
        let x = plane.vTime.values[idx]/TimeScale
        let y = plane.vAmplitudes[sliceIndex].values[idx]
        return float2(Float(x), Float(y))
    }
    
    // average delta x in graph
    func avgDX() -> Float {
        return Float(graphRect[2] - graphRect[0])/Float(pointsCount)
    }
}
