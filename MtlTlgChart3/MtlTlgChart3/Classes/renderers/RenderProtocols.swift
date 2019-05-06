//
//  RenderProtocols.swift
//  MtlTlgChart3
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
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
