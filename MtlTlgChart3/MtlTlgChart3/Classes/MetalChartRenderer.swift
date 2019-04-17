//
//  MetalChartRenderer.swift
//  GraphPresenter
//
//  Created by Andre on 3/27/19.
//  Copyright © 2019 BB. All rights reserved.
//

import Foundation
import MetalKit

// : IMetalSurfaceRenderer
class MetalChartRenderer: NSObject {
    var graph: GraphData? = nil
    var alpha: CGFloat = 1.0
    private var chart: ChartData?
    private var vertexBuffer: MTLBuffer!
    private var indexBuffer: MTLBuffer!
    
    /////////////
    let device: MTLDevice!
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    // absolute coordinates in graph values
    var viewportSize = vector_int4(1)
    // view.drawableSize (no need to keep it here)
    var screenSize = vector_int2(1)
    
    var pointsCount = 0
    var vertexCount:Int { get { return pointsCount * 2 } }
    var strokeColor:UIColor?
    var lineWidth = Float(1.5)
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device
    init(mtkView: MTKView) {
        device = mtkView.device
        super.init()
        loadMetal(mtkView: mtkView)
    }
    
    private var plane:Plane? = nil
    
    func setPlane(_ plane:Plane) {
        self.plane = plane
        let count1 = plane.vTime.count
        let countP = plane.vAmplitudes.count
        let count2 = plane.vAmplitudes[0].count
        print("set new plane with \(countP) amplitudes and [\(count1):\(count2)] points")
        
        pointsCount = min(count1, count2)
        guard pointsCount > 1 else {
            print("too few points in graph (\(pointsCount))")
            pointsCount = 0
            viewportSize = vector_int4(1)
            return
        }

        // next create buffers and start drawing
        guard let device = self.device else {
            return
        }
        
        let vertexMemSize = MemoryLayout<ChartRenderVertex>.stride * pointsCount * 2
        let totalIndexCount = pointsCount * 6 // not exactly
        let indexMemSize = MemoryLayout<UInt16>.stride * pointsCount * 6
        indexBuffer = device.makeBuffer(length: indexMemSize, options: .cpuCacheModeWriteCombined)
        vertexBuffer = device.makeBuffer(length: vertexMemSize, options: .cpuCacheModeWriteCombined)
        
        guard let vertexMemArray = vertexBuffer?.contents().bindMemory(to: ChartRenderVertex.self, capacity: pointsCount) else {
            print("no vertex array")
            return
        }
        
        guard let indexMemArray = indexBuffer?.contents().bindMemory(to: UInt16.self, capacity: totalIndexCount) else {
            print("no index array")
            return
        }
        
        //TODO: double conversion: repack coordinates
        var points = [float2]()
        for i in 0 ..< pointsCount {
            let x = plane.vTime.values[i]/1000
            let y = plane.vAmplitudes[0].values[i]
            let p = float2(Float(x), Float(y))
            points.append(p)
        }
        let minX = Int32(plane.vTime.minValue/1000)
        let maxX = Int32(plane.vTime.maxValue/1000)
        let minY = Int32(plane.vAmplitudes[0].minValue)
        let maxY = Int32(plane.vAmplitudes[0].maxValue)
        viewportSize = vector_int4(minX, minY, maxX, maxY)
        strokeColor = plane.vAmplitudes[0].color
        
        let vb = vertexMemArray
        let ib = indexMemArray

        for iPoint in 0 ..< pointsCount {
            let isLast = iPoint >= pointsCount - 1
            let currPt = points[iPoint]
            let prevPt = iPoint == 0 ? float2(x: currPt.x - 1, y: currPt.y) : points[iPoint - 1]
            let nextPt = isLast ? float2(x: currPt.x + 1, y: currPt.y) : points[iPoint + 1]

            var vx1 = ChartRenderVertex()
            vx1.position = currPt
            vx1.direction = 1
            vx1.normal = float2(x: prevPt.y - currPt.y, y: currPt.x - prevPt.x)
            vx1.nextNormal = float2(x: currPt.y - nextPt.y, y: nextPt.x - currPt.x)

            var vx2 = vx1
            vx2.direction = -1

            let vertexIndex = iPoint * 2
            vb[vertexIndex] = vx1
            vb[vertexIndex + 1] = vx2

            if !isLast {
                var ibi = iPoint * 6
                ib[ibi] = UInt16(vertexIndex)
                ibi += 1
                ib[ibi] = UInt16(vertexIndex + 2)
                ibi += 1
                ib[ibi] = UInt16(vertexIndex + 3)
                ibi += 1
                ib[ibi] = UInt16(vertexIndex)
                ibi += 1
                ib[ibi] = UInt16(vertexIndex + 3)
                ibi += 1
                ib[ibi] = UInt16(vertexIndex + 1)
            }
        }
    }
    
    /// Create our Metal render state objects including our shaders and render state pipeline objects
    private func loadMetal(mtkView: MTKView!) {
        guard let device = self.device else {
            print("no metal device")
            return
        }

        let defaultLibrary = device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShader")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Pipeline"
        pipelineStateDescriptor.sampleCount = mtkView.sampleCount
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        if let renderAttachment = pipelineStateDescriptor.colorAttachments[0] {
            renderAttachment.isBlendingEnabled = true
            renderAttachment.alphaBlendOperation = .add
            renderAttachment.rgbBlendOperation = .add
            renderAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
        
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineStateDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch {
            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
            //  If the Metal API validation is enabled, we can find out more information about what
            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
            //  from Xcode)
            print("Failed to created pipeline state, error \(error.localizedDescription)")
        }
        
        commandQueue = device.makeCommandQueue()
    }

    // original method
    func setupWithView(_ view: MTKView) {
        let device = view.device!
        
        let totalSpriteVertexCount = 400;
        let totalIndexCount = totalSpriteVertexCount * 6;
        
        let spriteVertexBufferSize = totalSpriteVertexCount * MemoryLayout<ChartRenderVertex>.stride
        let spriteIndexBufferSize = totalIndexCount * MemoryLayout<UInt16>.size
        
        self.vertexBuffer = device.makeBuffer(length: spriteVertexBufferSize, options: MTLResourceOptions.cpuCacheModeWriteCombined)!
        let vb = self.vertexBuffer.contents().bindMemory(to: ChartRenderVertex.self, capacity: totalSpriteVertexCount)
        vb.initialize(repeating: ChartRenderVertex(), count: totalSpriteVertexCount)
        
        self.indexBuffer = device.makeBuffer(length: spriteIndexBufferSize, options: MTLResourceOptions.cpuCacheModeWriteCombined)!
        let ib = self.indexBuffer.contents().bindMemory(to: UInt16.self, capacity: totalIndexCount)
        ib.initialize(repeating: UInt16(0), count: totalIndexCount)
    }
}

extension MetalChartRenderer: MTKViewDelegate {
    /// Called whenever view changes orientation or is resized
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Save the size of the drawable as we'll pass these
        //   values to our vertex shader when we draw
        screenSize.x = Int32(size.width)
        screenSize.y = Int32(size.height)
    }
    
    /// Called whenever the view needs to render a frame
    func draw(in view: MTKView) {
        guard let vertexBuffer = self.vertexBuffer else {
            //print("no vertex buffer, skip draw")
            return
        }
        
        guard vertexCount > 3 else {
            print("too few vertices in buffer, skip draw (\(vertexCount))")
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

        //TODO: maybe use it
//        let viewport = MTLViewport(originX: 0, originY: 0,
//                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
//                                   znear: -1, zfar: 1)
//        // Set the region of the drawable to which we'll draw.
//        renderEncoder.setViewport(viewport)
        
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
        
        renderEncoder.setCullMode(.none)

        updateDrawPipeline(view: view, encoder: renderEncoder, color: strokeColor)
        
        renderEncoder.endEncoding()
        if let currentDrawable = view.currentDrawable {
            commandBuffer.present(currentDrawable)
        } else {
            print("no currentDrawable")
        }
        commandBuffer.commit()
    }

    func updateDrawPipeline(view: MTKView, encoder:MTLRenderCommandEncoder, color:UIColor?) {
        let viewSize = view.drawableSize
        let screenSize = vector_int2(Int32(viewSize.width), Int32(viewSize.height))
        let indexCount = (pointsCount - 1) * 6;
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        let colorVector = UIColor.vector(color)

        var chartContext = ChartContext(viewportSize: viewportSize, screenSize: screenSize, color: colorVector, lineWidth:lineWidth, vertexCount:UInt32(vertexCount))

        encoder.setVertexBuffer(vertexBuffer, offset: 0,
                                index: Int(AAPLVertexInputIndexVertices.rawValue))
        encoder.setVertexBytes(&chartContext, length: MemoryLayout<ChartContext>.stride,
                               index: Int(AAPLVertexInputIndexChartContext.rawValue))

        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: indexCount,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset:0)
    }
}
