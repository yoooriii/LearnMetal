//
//  RenderProtocols.swift
//  MtlTlgChart3
//
//  Created by Leonid Lokhmatov on 4/24/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

protocol GraphRendererProto {
    var lineWidth: Float { get set }
    var graphRect:float4 { get set }

    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView)
    // it returns the original graph rect in comparision to the graphRect var
    func getOriginalGraphRect() -> float4
}
