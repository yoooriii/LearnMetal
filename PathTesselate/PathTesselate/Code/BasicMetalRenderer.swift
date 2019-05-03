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
    let fragmentFuncName = "fragmentShader"
    
    private var pathMesh:PathMesh?

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

    func setPath(_ path: CGPath) {
        pathMesh = nil
        
        guard let device = self.device else {
            print("no device")
            return
        }
        
        let contour = ContourHandler()
        contour.debugLevel = 1
        contour.evaluatePath(path)
        print("evaluated \(contour.count) points")
        pathMesh = contour.createMesh(with:device)
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

        // Real drawing happens here
        fillEncoder(renderEncoder, mtkView: view)
        
        renderEncoder.endEncoding()
        commandBuffer.present(currentDrawable)
        // Finalize rendering here & push the command buffer to the GPU
        commandBuffer.commit()
    }
    
    /// Called whenever view changes orientation or is resized
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // not sure if it is needed
        viewportSize.x = UInt32(size.width)
        viewportSize.y = UInt32(size.height)
    }
}

private extension BasicMetalRenderer {
    func fillEncoder(_ encoder:MTLRenderCommandEncoder, mtkView:MTKView) {
        guard let pathMesh = self.pathMesh,
            let vertexBuffer = pathMesh.vertexBuffer,
            let indexBuffer = pathMesh.indexBuffer,
            pathMesh.indexCount > 0
            else { return }
        
        let strokeColor = float4(0.5, 0.1, 0.1, 1.0)
        let fillColor = float4(0.0, 1.0, 0.0, 1.0)
        var renderCx = AAPLRenderContext(strokeColor: strokeColor, fillColor: fillColor, viewportSize:viewportSize)
        encoder.setVertexBytes(&renderCx,
                               length: MemoryLayout<AAPLRenderContext>.stride,
                               index: Int(AAPLVertexInputIndexRenderContext.rawValue))
        
        let indexCount = Int(pathMesh.indexCount)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(AAPLVertexInputIndexVertices.rawValue))
        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: indexCount,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset:0)
        
        //        return
        //
        //        let vertexCount = Int(pathMesh.vertexCount)
        //        renderCx.strokeColor = vector_float4(1.0, 1.0, 1.0, 1.0)
        //        encoder.setVertexBytes(&renderCx,
        //                               length: MemoryLayout<AAPLRenderContext>.stride,
        //                               index: Int(AAPLVertexInputIndexRenderContext.rawValue))
        //
        //        let drawIndexSceleton = true
        //        if drawIndexSceleton {
        //            encoder.drawIndexedPrimitives(type: .lineStrip,
        //                                          indexCount: indexCount,
        //                                          indexType: .uint16,
        //                                          indexBuffer: indexBuffer,
        //                                          indexBufferOffset:0)
        //        } else {
        //            encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertexCount)
        //        }
    }
    
    func makeViewport() -> MTLViewport? {
        return nil
        // Set the region of the drawable to which we'll draw.
        let viewport = MTLViewport(originX:0, originY:0,
                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
                                   znear: -1.0, zfar: 1.0)
        return viewport
    }
}
