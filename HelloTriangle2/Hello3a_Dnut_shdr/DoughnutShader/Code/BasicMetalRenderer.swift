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
    private var msaaTexture: MTLTexture?
    private var renderVertices:[float2]?
    var infoDelegate:InfoDelegate?

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
        mtkView.sampleCount = 4 // default=1
        mtkView.colorPixelFormat = .bgra8Unorm
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
        
        let fillColor1 = float4(0.6, 0.1, 0.1, 1.0)
        let fillColor2 = float4(1.0)
        var renderCx:RenderContext = RenderContext(strokeColor: float4(1), fillColor: fillColor1, viewportSize: viewportSize, rotation: 0, animeValue: 0);
        
        encoder.setVertexBytes(renderVertices,
                               length: MemoryLayout<float2>.stride * renderVertices.count,
                               index: Int(MetalIndexVertices))
        
        encoder.setVertexBytes(&renderCx,
                               length: MemoryLayout<RenderContext>.stride,
                               index: Int(MetalIndexRenderContext))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: renderVertices.count)
        
        
        renderCx.fillColor = fillColor2
        encoder.setVertexBytes(&renderCx,
                               length: MemoryLayout<RenderContext>.stride,
                               index: Int(MetalIndexRenderContext))
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: renderVertices.count)
    }
    
//    func makeViewport() -> MTLViewport? {
//        // Set the region of the drawable to which we'll draw.
//        let viewport = MTLViewport(originX:0, originY:0,
//                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
//                                   znear: -1.0, zfar: 1.0)
//        return viewport
//    }
    
    private func makeTexture(size:uint2) -> MTLTexture? {
        let desc = MTLTextureDescriptor()
        desc.textureType = MTLTextureType.type2DMultisample
        desc.width = Int(size.x)
        desc.height = Int(size.y)
        desc.sampleCount = 4
        desc.pixelFormat = .bgra8Unorm
        desc.usage = MTLTextureUsage.renderTarget // it fixes crash under xcode debugger
        
        return device.makeTexture(descriptor: desc)
    }

    func makeTestCircularVertices(rect: CGRect, steps:Int) -> [float2] {
        var positions = [float2]()
        if steps < 3 {
            print("too few steps \(steps)")
            return positions
        }
        
        let maxR = Float(min(rect.width, rect.height) * 0.5)
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
        
        guard let currentDrawable = view.currentDrawable else {
            print("no currentDrawable")
            return
        }

        // MSAA : set a texture to smooth lines (antialiasing)
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = msaaTexture
        renderPassDescriptor.colorAttachments[0].resolveTexture = currentDrawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.4, blue: 0.5, alpha: 0.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("cannot make render encoder")
            commandBuffer.commit()
            return
        }
        renderEncoder.label = "My Simple Render Encoder"
        
//        if let viewport = makeViewport() {
//            //renderEncoder.setViewport(viewport)
//        }

        renderEncoder.setRenderPipelineState(pipelineState)
        
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
        
        // recreate texture to fit the size
        msaaTexture = makeTexture(size: viewportSize)

        let rect = CGRect(x:0, y: 0, width: size.width, height: size.height)
        renderVertices = makeTestCircularVertices(rect: rect, steps: 12)
        
        let count = (renderVertices?.count == nil) ? 0 : renderVertices!.count
        let info = "canvas: \(Int(size.width))x\(Int(size.height)); vertices:[\(count)]"
        print(info)
        if let infoDelegate = infoDelegate {
            infoDelegate.setInfo(text: info)
        }
    }
}
