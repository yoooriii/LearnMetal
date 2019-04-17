//
//  AAPLRenderer.swift
//  BasicBuffers_sw
//
//  Created by Leonid Lokhmatov on 4/17/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit
import simd

class AAPLRenderer: NSObject {
    let device: MTLDevice!
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    
    // GPU buffer which will contain our vertex array
    var vertexBuffer: MTLBuffer?

    var viewportSize = vector_uint2(1, 1)

    var numVertices = 0
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device
    init(mtkView: MTKView) {
        device = mtkView.device
        super.init()
        loadMetal(mtkView: mtkView)
    }
    
    /// Creates a grid of 25x15 quads (i.e. 72000 bytes with 2250 vertices are to be loaded into
    ///   a vertex buffer)
    static private func makeVertexBuffer(device:MTLDevice!) -> (buffer:MTLBuffer?, count:Int) {
        // AAPLVertex content: Pixel positions
        let coordinates:[vector_float2] = [
            vector_float2(-20,  20),
            vector_float2( 20,  20),
            vector_float2(-20, -20),
            vector_float2( 20, -20),
            vector_float2(-20, -20),
            vector_float2( 20,  20)
        ]
        // AAPLVertex content: RGBA colors
        let colors:[vector_float4] = [
            vector_float4(1, 0, 0, 1),
            vector_float4(0, 0, 1, 1),
            vector_float4(0, 1, 0, 1),
            vector_float4(0.1, 0.7, 0.3, 1),
            vector_float4(0, 1, 0, 1),
            vector_float4(0, 0, 1, 1)
        ]
        
        // Quad grid parameters
        let NUM_COLUMNS = 25
        let NUM_ROWS = 15
        let NUM_VERTICES_PER_QUAD = coordinates.count
        let QUAD_SPACING = Float(50.0)

        let verticesCount = NUM_VERTICES_PER_QUAD * NUM_COLUMNS * NUM_ROWS
        let dataSize = MemoryLayout<AAPLVertex>.stride * verticesCount
        // Create a vertex buffer by allocating storage that can be read by the GPU
        let vertexBuffer = device.makeBuffer(length: dataSize, options: .cpuCacheModeWriteCombined)
        guard let vertexMemArray = vertexBuffer?.contents().bindMemory(to: AAPLVertex.self, capacity: verticesCount) else {
            return (buffer:nil, count:0)
        }
        
        let minX = -Float(NUM_COLUMNS) * QUAD_SPACING / 2.0 + QUAD_SPACING/2.0
        let minY = -Float(NUM_ROWS)    * QUAD_SPACING / 2.0 + QUAD_SPACING/2.0
        var i = 0
        var upperLeftPosition = vector_float2(x: minX, y: minY)
        for _ in 0..<NUM_ROWS {
            for _ in 0..<NUM_COLUMNS {
                // copy 6 vertices of one quad into the memory array
                for iv in 0..<NUM_VERTICES_PER_QUAD {
                    let color = colors[iv]
                    let coord = coordinates[iv] + upperLeftPosition
                    let vx = AAPLVertex(position:coord, color:color)
                    vertexMemArray[i] = vx
                    i += 1
                }
                upperLeftPosition.x += QUAD_SPACING
            }
            upperLeftPosition.x = minX
            upperLeftPosition.y += QUAD_SPACING
        }
        
        return (buffer:vertexBuffer, count:i)
    }
    
    /// Create our Metal render state objects including our shaders and render state pipeline objects
    private func loadMetal(mtkView: MTKView!) {
        guard let device = self.device else {
            print("no metal device")
            return
        }
//        mtkView.colorPixelFormat = .bgra8Unorm_srgb //MTLPixelFormatBGRA8Unorm_sRGB;
    
        let defaultLibrary = device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShader")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Pipeline"
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            print("Failed to created pipeline state, error \(error.localizedDescription)")
        }
        
        let packedBuffer = AAPLRenderer.makeVertexBuffer(device:device)
        numVertices = packedBuffer.count
        guard let vertexBuffer = packedBuffer.buffer else {
            print("cannot create vertex buffer")
            return
        }
        self.vertexBuffer = vertexBuffer
        
        commandQueue = device.makeCommandQueue()
    }
}

extension AAPLRenderer: MTKViewDelegate {
    /// Called whenever view changes orientation or is resized
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Save the size of the drawable as we'll pass these
        //   values to our vertex shader when we draw
        viewportSize.x = UInt32(size.width)
        viewportSize.y = UInt32(size.height)
    }
    
    /// Called whenever the view needs to render a frame
    func draw(in view: MTKView) {
        guard let vertexBuffer = self.vertexBuffer else {
            print("no vertex buffer, skip draw")
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("cannot create command buffer")
            return
        }
        commandBuffer.label = "MyCommandBuffer"
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            print("cannot get currentRenderPassDescriptor")
            return
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("cannot make render encoder")
            return
        }
        renderEncoder.label = "MyRenderEncoder"
        
        let viewport = MTLViewport(originX: 0, originY: 0,
                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
                                   znear: -1, zfar: 1)
        // Set the region of the drawable to which we'll draw.
        renderEncoder.setViewport(viewport)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // We call -[MTLRenderCommandEncoder setVertexBuffer:offset:atIndex:] to send data in our
        //   preloaded MTLBuffer from our ObjC code here to our Metal 'vertexShader' function
        // This call has 3 arguments
        //   1) buffer - The buffer object containing the data we want passed down
        //   2) offset - They byte offset from the beginning of the buffer which indicates what
        //      'vertexPointer' point to.  In this case we pass 0 so data at the very beginning is
        //      passed down.
        //      We'll learn about potential uses of the offset in future samples
        //   3) index - An integer index which corresponds to the index of the buffer attribute
        //      qualifier of the argument in our 'vertexShader' function.  Note, this parameter is
        //      the same as the 'index' parameter in
        //              -[MTLRenderCommandEncoder setVertexBytes:length:atIndex:]
        //
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index:Int(AAPLVertexInputIndexVertices.rawValue))
        
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: Int(AAPLVertexInputIndexViewportSize.rawValue))
        // Draw the vertices of the quads
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: numVertices)
        
        renderEncoder.endEncoding()
        if let currentDrawable = view.currentDrawable {
            commandBuffer.present(currentDrawable)
        } else {
            print("no currentDrawable")
        }
        commandBuffer.commit()
    }
}
