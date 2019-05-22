//
//  GeometryUtils.swift
//  MtlTlgChart3
//
//  Created by Leonid Lokhmatov on 5/11/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import simd

extension float4 {
    var width: Float {
        get { return self[2] }
        set { self[2] = newValue }
    }
    var maxX: Float {
        get { return self[0] + self[2] }
    }
    var height: Float {
        get { return self[3] }
        set { self[3] = newValue }
    }
    var maxY: Float {
        get { return self[1] + self[3] }
    }
}

extension float2 {
    var w: Float {
        get { return self[1] }
        set { self[1] = newValue }
    }
}
