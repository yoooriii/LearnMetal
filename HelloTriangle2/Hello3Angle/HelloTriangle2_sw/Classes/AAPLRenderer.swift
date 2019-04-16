/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Implementation of our platform independent renderer class, which performs Metal setup and per frame rendering
 */

//  Apple's example converted to swift
//  AAPLRenderer.swift
//  HelloTriangle2(sw)
//
//  Created by Leonid Lokhmatov on 4/15/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit
import simd

// Main class performing the rendering
class AAPLRenderer: NSObject {
    // The device (aka GPU) we're using to render
    private let device: MTLDevice!
    // Our render pipeline composed of our vertex and fragment shaders in the .metal shader file
    private let pipelineState: MTLRenderPipelineState!
    // The command Queue from which we'll obtain command buffers
    private let commandQueue: MTLCommandQueue!
    // The current size of our view so we can use this in our render pipeline
    private var viewportSize: vector_uint2 = vector_uint2(0)
    // vertices data (Triangle or else)
    private var vertices = [AAPLVertex]()
    //
    private var viewport: MTLViewport?
    
    private let mtkView: MTKView!
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device
    init?(metalKitView mtkView: MTKView!) {
        self.mtkView = mtkView
        device = mtkView.device
        guard device != nil else {
            print("no metal device on view \(String(describing: mtkView))")
            return nil
        }
        
        // Load all the shader files with a .metal file extension in the project
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            print("cannot create library with device \(String(describing: device))")
            return nil
        }
        
        // Load the vertex function from the library
        guard let vertexFunction = defaultLibrary.makeFunction(name: "vertexShader") else {
            print("cannot load vertex shader")
            return nil
        }
        
        // Load the fragment function from the library
        guard let fragmentFunction = defaultLibrary.makeFunction(name:"fragmentShader") else {
            print("cannot load fragment shader")
            return nil
        }
        
        // Configure a pipeline descriptor that is used to create a pipeline state
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Pipeline"
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;
        
        do {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch {
            print("cannot create pipeline with descriptor \(pipelineStateDescriptor)")
            return nil
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            print("cannot create command queue")
            return nil
        }
        self.commandQueue = commandQueue
    }
    
    func setOffset(x:Double, y:Double) {
        viewport = MTLViewport(originX:x , originY:y,
                               width: Double(viewportSize.x), height: Double(viewportSize.y),
                               znear: -1.0, zfar: 1.0)
    }
}

private extension AAPLRenderer {
    func makeTestVertices(size: CGSize) -> [AAPLVertex] {
        var resVertices = [AAPLVertex]()

        let color0 = float4(x:0.0, y:1.0, z:0.0, w: 1.0)
        let maxX = Float(size.width / 2.0)
        let maxY = Float(size.height / 2.0) * 0.9
        var x = -maxX
        let steps = 3
        let dx = maxX/Float(steps)

        let pos = float2(x, 0.0) // start point
        let vertex = AAPLVertex(position:pos, color:color0)
        resVertices.append(vertex)

        while x < maxX {
            x += dx
            for i in 0..<2 {
                let y = (0 == i) ? maxY : -maxY
                let pos = float2(x, y)
                let vertex = AAPLVertex(position:pos, color:color0)
                resVertices.append(vertex)
            }
        }
        
        return resVertices
    }
    
    func makeVerticesForViewSize(_ size: CGSize, padding: CGFloat) -> [AAPLVertex] {
        let maxX = Float(size.width / 2.0 - padding)
        let maxY = Float(size.height / 2.0 - padding)
        
        let color0 = float4(x:1.0, y:0.0, z:0.0, w: 1.0)
        let color1 = float4(x:0.0, y:1.0, z:0.0, w: 1.0)
        let color2 = float4(x:0.0, y:0.0, z:1.0, w: 1.0)
        let colors = [color0, color1, color2]
        
        var resVertices = [AAPLVertex]()
        let steps = 12
        let pi2 = Float.pi * 2.0
        let da = pi2 / Float(steps)
        var a = Float(0)
        while (a <= pi2 * 2.0) {
            for i in 0..<3 {
                let pos:float2
                if i == 0 {
                    pos = float2(0.0)
                } else {
                    pos = float2(sin(a) * maxX, cos(a) * maxY)
                }
                if i == 1 {
                    a += da
                }
                let color = colors[i]
                let vertex = AAPLVertex(position:pos, color:color)
                resVertices.append(vertex)
            }
        }
        
        return resVertices
    }
    
    func makeNormalVertices() -> [AAPLVertex] {
        return makeVerticesForViewSize(CGSize(width: 1.0, height: 1.0), padding: 0.0)
    }
}

extension AAPLRenderer: MTKViewDelegate {
  
    /// Called whenever the view needs to render a frame
    func draw(in view: MTKView) {
        guard let _ = viewport else {
            print("no viewport, skip")
            return
        }

        // Create a new command buffer for each render pass to the current drawable
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("cannot create command buffer")
            return
        }
        
        commandBuffer.label = "MyCommand"
        
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
        
        renderEncoder.label = "MyRenderEncoder"
        
        // Set the region of the drawable to which we'll draw.
        //        let viewport = MTLViewport(originX:offsetX , originY:offsetY,
        //                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
        //                                   znear: -1.0, zfar: 1.0)
        if let viewport = viewport {
            renderEncoder.setViewport(viewport)
        }
        renderEncoder.setRenderPipelineState(pipelineState)
        
        
        let triangleVertices = vertices
        // We call -[MTLRenderCommandEncoder setVertexBytes:length:atIndex:] to send data from our
        //   Application ObjC code here to our Metal 'vertexShader' function
        // This call has 3 arguments
        //   1) A pointer to the memory we want to pass to our shader
        //   2) The memory size of the data we want passed down
        //   3) An integer index which corresponds to the index of the buffer attribute qualifier
        //      of the argument in our 'vertexShader' function
        
        // You send a pointer to the `triangleVertices` array also and indicate its size
        // The `AAPLVertexInputIndexVertices` enum value corresponds to the `vertexArray`
        // argument in the `vertexShader` function because its buffer attribute also uses
        // the `AAPLVertexInputIndexVertices` enum value for its index
        renderEncoder.setVertexBytes(triangleVertices,
                                     length: MemoryLayout<AAPLVertex>.stride * triangleVertices.count,
                                     index: Int(AAPLVertexInputIndexVertices.rawValue))
        
        // You send a pointer to `_viewportSize` and also indicate its size
        // The `AAPLVertexInputIndexViewportSize` enum value corresponds to the
        // `viewportSizePointer` argument in the `vertexShader` function because its
        //  buffer attribute also uses the `AAPLVertexInputIndexViewportSize` enum value
        //  for its index
//        renderEncoder.setVertexBytes(&viewportSize,
//                                     length: MemoryLayout<simd_uint2>.stride,
//                                     index: Int(AAPLVertexInputIndexViewportSize.rawValue))

        // set context: colors & viewport size
        let strokeColor = vector_float4(1.0, 0.2, 0.2, 1.0)
        let fillColor = vector_float4(0.0, 1.0, 0.0, 1.0)
        let additionalColors = (vector_float4(0.0), vector_float4(0.0), vector_float4(0.0), vector_float4(0.0))
        var renderCx = AAPLRenderContext(strokeColor:strokeColor, fillColor:fillColor, viewportSize:viewportSize, additionalColors:additionalColors)
        renderEncoder.setVertexBytes(&renderCx,
                                     length: MemoryLayout<AAPLRenderContext>.stride,
                                     index: Int(AAPLVertexInputIndexRenderContext.rawValue))
        
        
        
        
        // Draw the 3 vertices of our triangle
        renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: triangleVertices.count)
        renderEncoder.endEncoding()
        
        // Schedule a present once the framebuffer is complete using the current drawable
        if let currentDrawable = view.currentDrawable {
            commandBuffer.present(currentDrawable)
        } else {
            print("view has no drawable")
        }
        
        // Finalize rendering here & push the command buffer to the GPU
        commandBuffer.commit()
    }

    /// Called whenever view changes orientation or is resized
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Save the size of the drawable as we'll pass these
        //   values to our vertex shader when we draw
        viewportSize.x = UInt32(size.width)
        viewportSize.y = UInt32(size.height)

//        let padding = min(size.width, size.height) * 0.2
//        vertices = makeVerticesForViewSize(size, padding: padding)

//        let sz1 = CGSize(width: 1.0, height: 1.0)
//        vertices = makeVerticesForViewSize(sz1, padding: 0)

        vertices = makeTestVertices(size: size)
        
        viewport = MTLViewport(originX:0, originY:0, // offset?
                               width: Double(size.width), height: Double(size.height),
                               znear: -1.0, zfar: 1.0)
    }
}
