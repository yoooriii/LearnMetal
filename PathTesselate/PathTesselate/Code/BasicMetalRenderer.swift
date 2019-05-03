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
    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?
    private var viewportSize: vector_uint2 = vector_uint2(0)
    // Define shader function names here
    let vertexFuncName = "vertexShader"
    let fragmentFuncName = "fragmentShader"
    
    private var pathMesh:PathMesh?
    private var msaaTexture: MTLTexture?

    //MARK: -

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
        
        super.init()

        mtkView.delegate = self
        mtkView.sampleCount = 4 // default=1
        mtkView.colorPixelFormat = .bgra8Unorm
        renderPipelineDescriptor.sampleCount = mtkView.sampleCount
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        renderPipelineDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        // make pipelineState async (dont block main thread)
        device.makeRenderPipelineState(descriptor: renderPipelineDescriptor) { (pipelineState, error) in
            self.pipelineState = pipelineState
            if let error = error {
                // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
                //  If the Metal API validation is enabled, we can find out more information about what
                //  went wrong.  (Metal API validation is enabled by default when a debug build is run
                //  from Xcode)
                print("Failed to created pipeline state, error \(error.localizedDescription)")
            } else {
                self.commandQueue = self.device.makeCommandQueue()
            }
        }
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
        guard let commandQueue = self.commandQueue,
        let pipelineState = self.pipelineState
            else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("cannot create command buffer")
            return
        }
        commandBuffer.label = "My Simple Command Buffer"

        guard let currentDrawable = view.currentDrawable else {
            print("no currentDrawable")
            return
        }
        
        guard let renderPassDescriptor = makeRenderPassDescriptor(view: view) else {
            print("no renderPassDescriptor")
            return
        }
        
        renderPassDescriptor.colorAttachments[0].resolveTexture = currentDrawable.texture
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("cannot make render encoder")
            return
        }
        renderEncoder.label = "My Simple Render Encoder"
        
        if let viewport = makeViewport() {
            renderEncoder.setViewport(viewport)
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setCullMode(.none)

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
        
        // reset cached texture, it will be recreated on a next draw pass
        msaaTexture = nil
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
    }
    
    func makeViewport() -> MTLViewport? {
        return nil
        // Set the region of the drawable to which we'll draw.
        let viewport = MTLViewport(originX:0, originY:0,
                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
                                   znear: -1.0, zfar: 1.0)
        return viewport
    }
    
    func makeMSAATexture(size:vector_int2) -> MTLTexture? {
        let desc = MTLTextureDescriptor()
        desc.textureType = MTLTextureType.type2DMultisample
        desc.width = Int(size.x)
        desc.height = Int(size.y)
        desc.sampleCount = 4
        desc.pixelFormat = .bgra8Unorm
        desc.usage = MTLTextureUsage.renderTarget // it fixes crash under xcode debugger
        desc.storageMode = .memoryless
        
        return device.makeTexture(descriptor: desc)
    }
    
    func makeRenderPassDescriptor(view: MTKView) -> MTLRenderPassDescriptor? {
        if let _ = msaaTexture { /* use cached tx */ } else {
            let drawableSize = view.drawableSize
            let size = vector_int2(Int32(drawableSize.width), Int32(drawableSize.height))
            // MSAA : set a texture to smooth lines (antialiasing)
            msaaTexture = makeMSAATexture(size: size)
        }
        let rPassDescriptor = MTLRenderPassDescriptor()
        rPassDescriptor.colorAttachments[0].texture = msaaTexture
        //        rPassDescriptor.colorAttachments[0].resolveTexture = currentDrawable.texture
        rPassDescriptor.colorAttachments[0].loadAction = .clear
        rPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.4, blue: 0.5, alpha: 0.0)
        rPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        
        return rPassDescriptor
    }
}
