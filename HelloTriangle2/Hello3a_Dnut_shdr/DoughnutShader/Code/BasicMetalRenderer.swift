//
//  BasicMetalRenderer.swift
//  MetalTemplate
//
//  Created by Leonid Lokhmatov on 4/19/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import MetalKit

public class BasicMetalRenderer: NSObject {
    var mtkView: MTKView!
    var device: MTLDevice!
    private let pipelineState: MTLRenderPipelineState!
    private let commandQueue: MTLCommandQueue!
    private var viewportSize: vector_uint2 = vector_uint2(0)
    // Define shader function names here
    let vertexFuncName = "vertexShader"
    let fragmentFuncName = "simpleFragmentShader"
    //
    private var renderVertices:[float2]?

    public init?(mtkView: MTKView!) {
        self.mtkView = mtkView
        if let dev = mtkView.device {
            device = dev
        } else {
            guard let dev = MTLCreateSystemDefaultDevice() else {
                print("Metal is not supported on this device")
                return nil
            }
            device = dev
            mtkView.device = dev
        }

        // Load all the shader files with a .metal file extension in the project
        guard let library = device.makeDefaultLibrary() else {
            print("cannot create library with device \(String(describing: device))")
            return nil
        }
        
        // Configure a pipeline descriptor that is used to create a pipeline state
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.label = "Simple Pipeline"
        renderPipelineDescriptor.sampleCount = mtkView.sampleCount
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        renderPipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        // Load the vertex function from the library
        if let vertexFunction = library.makeFunction(name: vertexFuncName) {
            renderPipelineDescriptor.vertexFunction = vertexFunction
        } else {
            print("cannot load func '\(vertexFuncName)'")
        }
        
        // Load the fragment function from the library
        if let fragmentFunction = library.makeFunction(name: fragmentFuncName) {
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
        } else {
            print("cannot load func '\(fragmentFuncName)'")
        }

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print("cannot create pipeline \(error.localizedDescription)")
            return nil
        }
        
        guard let deviceCommandQueue = device.makeCommandQueue() else {
            print("cannot create command queue")
            return nil
        }
        commandQueue = deviceCommandQueue

        super.init()
        mtkView.delegate = self
    }
}


private extension BasicMetalRenderer {
    func fillEncoder(_ encoder:MTLRenderCommandEncoder, mtkView:MTKView) {
        guard let renderVertices = self.renderVertices else {
            return
        }
        
        var renderCx:RenderContext = RenderContext(strokeColor: float4(1), fillColor: float4(1,0,0,1), viewportSize: viewportSize, rotation: 0, animeValue: 0);
        
        encoder.setVertexBytes(renderVertices,
                               length: MemoryLayout<float2>.stride * renderVertices.count,
                               index: Int(MetalIndexVertices))
        
        encoder.setVertexBytes(&renderCx,
                               length: MemoryLayout<RenderContext>.stride,
                               index: Int(MetalIndexRenderContext))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: renderVertices.count)
        
        
        renderCx.fillColor = float4(1)
        encoder.setVertexBytes(&renderCx,
                               length: MemoryLayout<RenderContext>.stride,
                               index: Int(MetalIndexRenderContext))
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: renderVertices.count)
    }
    
    func makeViewport() -> MTLViewport? {
        // Set the region of the drawable to which we'll draw.
        let viewport = MTLViewport(originX:0, originY:0,
                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
                                   znear: -1.0, zfar: 1.0)
        return viewport
    }
    
    
    func makeTestCircularVertices(rect: CGRect, steps:Int) -> [float2] {
        var positions = [float2]()
        if steps < 3 {
            print("too few steps \(steps)")
            return positions
        }
        
        let maxR = Float(min(rect.width, rect.height) * 0.45)
        let minR = maxR * 0.8
        let origin = float2(Float(rect.minX), Float(rect.minY))
        let pi2 = Float.pi * 2.0
        
        for i in 0 ..< steps * 2 {
            let a = pi2 * Float(i) / Float(steps * 2)
            let r = (i & 1 == 0) ? maxR : minR
            let pos = float2(sin(a), cos(a)) * r + origin
            positions.append(pos)
        }
        positions.append(positions[0])
        positions.append(positions[1])

        return positions
    }
}


//MARK - MTKViewDelegate
extension BasicMetalRenderer: MTKViewDelegate {
    
    /// Called whenever the view needs to render a frame
    public func draw(in view: MTKView) {
        // Create a new command buffer for each render pass to the current drawable
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("cannot create command buffer")
            return
        }
        commandBuffer.label = "My Simple Command Buffer"
        
        // Obtain a renderPassDescriptor generated from the view's drawable textures
        // MTLRenderPassDescriptor
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            commandBuffer.commit()
            print("cannot get render pass descriptor")
            return
        }
        
        // Create a render command encoder so we can render into something
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            commandBuffer.commit()
            print("cannot create render command encoder")
            return
        }
        renderEncoder.label = "My Simple Render Encoder"
        
        if let viewport = makeViewport() {
            renderEncoder.setViewport(viewport)
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        
        guard let currentDrawable = view.currentDrawable else {
            print("no drawable")
            renderEncoder.endEncoding()
            commandBuffer.commit()
            return
        }

        // Real drawing happens here if implemented
        fillEncoder(renderEncoder, mtkView: view)

        renderEncoder.endEncoding()
        commandBuffer.present(currentDrawable)
        // Finalize rendering here & push the command buffer to the GPU
        commandBuffer.commit()
    }
    
    /// Called whenever view changes orientation or is resized
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize.x = UInt32(size.width)
        viewportSize.y = UInt32(size.height)
        
        let rect = CGRect(x: 50, y: 50, width: 300, height: 300)
        renderVertices = makeTestCircularVertices(rect: rect, steps: 12)
        
        let count = (renderVertices?.count == nil) ? 0 : renderVertices!.count
        print("canvas: \(Int(size.width))x\(Int(size.height)); vertices:[\(count)]")
    }
}
