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
    var height: Float {
        get { return self[3] }
        set { self[3] = newValue }
    }
}

extension float2 {
    var w: Float {
        get { return self[1] }
        set { self[1] = newValue }
    }
}
