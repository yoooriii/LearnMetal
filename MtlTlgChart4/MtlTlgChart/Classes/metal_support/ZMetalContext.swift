//
//  ZMetalContext.swift
//  MtlTlgChart3
//
//  Created by Leonid Lokhmatov on 5/6/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

class ZMetalContext {
    let device:MTLDevice!
    var pipelineState: MTLRenderPipelineState?
    var commandQueue: MTLCommandQueue?
    var library:MTLLibrary?
    
    let vertexFuncName = "vertexShader"
    let fragmentFuncName = "fragmentShader"

    init(device:MTLDevice!) {
        self.device = device
    }
    
    func setupMetalView(_ mtkView:MTKView) {
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.sampleCount = 4
        mtkView.isOpaque = false
    }
    
    /// Create our Metal render state objects including our shaders and render state pipeline objects
    func loadMetalIfNeeded() {
        if let _ = pipelineState {
            // metal already loaded, skip the rest
            return
        }
        
        guard let device = self.device else {
            print("no metal device")
            return
        }
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Graph Pipeline"
        
        library = device.makeDefaultLibrary()
        if let defaultLibrary = library {
            if let vertexFunction = defaultLibrary.makeFunction(name: vertexFuncName) {
                pipelineStateDescriptor.vertexFunction = vertexFunction
            } else {
                print("Cannot load shader '\(vertexFuncName)'")
                return
            }
            
            if let fragmentFunction = defaultLibrary.makeFunction(name: fragmentFuncName) {
                pipelineStateDescriptor.fragmentFunction = fragmentFunction
            } else {
                print("Cannot load shader '\(vertexFuncName)'")
                return
            }
        } else {
            print("Failed to create default library")
            return
        }
        
        pipelineStateDescriptor.sampleCount = 4
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        //        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        //        pipelineStateDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        //        if let renderAttachment = pipelineStateDescriptor.colorAttachments[0] {
        //            renderAttachment.isBlendingEnabled = true
        //            renderAttachment.alphaBlendOperation = .add
        //            renderAttachment.rgbBlendOperation = .add
        //            renderAttachment.sourceRGBBlendFactor = .sourceAlpha
        //            renderAttachment.sourceAlphaBlendFactor = .sourceAlpha
        //            renderAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        //            renderAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        //        }
        
        // make pipelineState async (dont block main thread); or use the sync variant:
        // pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        device.makeRenderPipelineState(descriptor: pipelineStateDescriptor) { (pipelineState, error) in
            self.pipelineState = pipelineState
            if let error = error {
                // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
                //  If the Metal API validation is enabled, we can find out more information about what
                //  went wrong.  (Metal API validation is enabled by default when a debug build is run
                //  from Xcode)
                print("Failed to create pipeline state, error \(error.localizedDescription)")
            } else {
                self.commandQueue = device.makeCommandQueue()
                if nil == self.commandQueue {
                    print("Failed to create command Queue")
                }
            }
        }
    }
    
    typealias DrawBlock = (MTLRenderCommandEncoder) -> Void

    func draw(in view: MTKView, renderPassDescriptor:MTLRenderPassDescriptor?, drawBlock:DrawBlock) {
        guard let pipelineState = pipelineState else {
            return
        }
        
        guard let commandQueue = commandQueue else {
            print("no command queue")
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("cannot create command buffer")
            return
        }
        commandBuffer.label = "Graph Command Buffer"
        
        guard let currentDrawable = view.currentDrawable else {
            print("no currentDrawable")
            return
        }
        
        guard let renderPassDescriptor = renderPassDescriptor else {
            print("no renderPassDescriptor")
            return
        }
        
        renderPassDescriptor.colorAttachments[0].resolveTexture = currentDrawable.texture
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("cannot make render encoder")
            return
        }
        renderEncoder.label = "Graph Render Encoder"
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setCullMode(.none)
        
        drawBlock(renderEncoder)
        
        renderEncoder.endEncoding()
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
