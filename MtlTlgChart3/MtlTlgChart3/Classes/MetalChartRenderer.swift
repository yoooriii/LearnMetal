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
    
    var numVertices = 0
    var pointsCount = 0
    var strokeColor:UIColor?
    var lineWidth = Float(1.5)
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device
    init(mtkView: MTKView) {
        device = mtkView.device
        super.init()
        loadMetal(mtkView: mtkView)
        // next: create vertex buffer
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
            numVertices = 0
            pointsCount = 0
            viewportSize = vector_int4(1)
            return
        }
        numVertices = pointsCount * 2

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
        for i in 0..<pointsCount {
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
        
//        let indCount = (pointsCount - 1) * 5
        let vb = vertexMemArray
        let ib = indexMemArray
        var vx = ChartRenderVertex()
        vx.position = float2(0)
        vb[0] = vx
        
        //let vertexColor = float4(1, 0, 0, 1.0)  //TODO: use color + Float(self.alpha)
        //vertexColor = float4.init(Float(components[0]), Float(components[1]), Float(components[2]), Float(self.alpha))

        for vertexNumber in 0 ..< pointsCount {
            var vx = ChartRenderVertex()
            var vx2 = ChartRenderVertex()

            let isLast = vertexNumber >= pointsCount - 1
            let point = points[vertexNumber]
            
            let currentCoord = point
            let prevCoord: float2
            if vertexNumber == 0 {
                prevCoord = float2(x: currentCoord.x - 1, y: currentCoord.y)
            } else {
                prevCoord = points[vertexNumber - 1]
            }
            
            let nextCoord: float2
            if isLast {
                nextCoord = float2(x: currentCoord.x + 1, y: currentCoord.y)
            } else {
                nextCoord = points[vertexNumber + 1]
            }
            
            let leftNorm = float2(x: prevCoord.y - currentCoord.y, y: currentCoord.x - prevCoord.x)
            let rightNorm = float2(x: currentCoord.y - nextCoord.y, y: nextCoord.x - currentCoord.x)
            
            let vertexIndex = vertexNumber * 2
            
            vx.position = currentCoord
            vx.direction = 1
            vx.normal = leftNorm
            vx.nextNormal = rightNorm
            vb[vertexIndex] = vx
            
            vx2.position = currentCoord
            vx2.direction = -1
            vx2.normal = leftNorm
            vx2.nextNormal = rightNorm
            vb[vertexIndex + 1] = vx2

            if !isLast {
                var indexOffset = vertexNumber * 6
                ib[indexOffset] = UInt16(vertexIndex)
                indexOffset += 1
                ib[indexOffset] = UInt16(vertexIndex + 2)
                indexOffset += 1
                ib[indexOffset] = UInt16(vertexIndex + 3)
                indexOffset += 1
                ib[indexOffset] = UInt16(vertexIndex)
                indexOffset += 1
                ib[indexOffset] = UInt16(vertexIndex + 3)
                indexOffset += 1
                ib[indexOffset] = UInt16(vertexIndex + 1)
            }
        }
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
    
//    func updateChart(chart: ChartData) {
//        self.chart = chart
//    }
    
    func updateGeometry(_ chart: ChartData, vertexBuffer: MTLBuffer, indexBuffer: MTLBuffer) {
        let points = chart.points
        if points.isEmpty {
            return
        }
        
        let indCount = (points.count - 1) * 5
        let vb = vertexBuffer.contents().bindMemory(to: ChartRenderVertex.self, capacity: points.count)
        let ib = indexBuffer.contents().bindMemory(to: UInt16.self, capacity: indCount)
        vb[0].position.x = 0
        
        let vertexColor: float4
        if let components = chart.display?.color?.cgColor.components {
            vertexColor = float4.init(Float(components[0]), Float(components[1]), Float(components[2]), Float(self.alpha))
        } else {
            vertexColor = float4.init(0, 0, 0, Float(self.alpha))
        }
        
        for vertexNumber in 0 ..< points.count {
            let isLast = vertexNumber >= points.count - 1
            let point = points[vertexNumber]
            
            let currentCoord = point.coordinate
            let prevCoord: ChartData.ChartCoordinate
            if vertexNumber == 0 {
                prevCoord = ChartData.ChartCoordinate.init(x: currentCoord.x - 1, y: currentCoord.y)
            } else {
                prevCoord = points[vertexNumber - 1].coordinate
            }
            
            let nextCoord: ChartData.ChartCoordinate
            if isLast {
                nextCoord = ChartData.ChartCoordinate.init(x: currentCoord.x + 1, y: currentCoord.y)
            } else {
                nextCoord = points[vertexNumber + 1].coordinate
            }
            
            let leftNorm = CGPoint.init(x: -(currentCoord.y - prevCoord.y), y: currentCoord.x - prevCoord.x)
            let rightNorm = CGPoint.init(x: -(nextCoord.y - currentCoord.y), y: nextCoord.x - currentCoord.x)
            
            let vertexIndex = vertexNumber * 2
            
            vb[vertexIndex + 0].position.x = Float(currentCoord.x)
            vb[vertexIndex + 0].position.y = Float(currentCoord.y)
            vb[vertexIndex + 0].color = vertexColor
            vb[vertexIndex + 0].direction = 1
            
            vb[vertexIndex + 0].normal.x = Float(leftNorm.x)
            vb[vertexIndex + 0].normal.y = Float(leftNorm.y)
            
            vb[vertexIndex + 0].nextNormal.x = Float(rightNorm.x)
            vb[vertexIndex + 0].nextNormal.y = Float(rightNorm.y)
            
            
            vb[vertexIndex + 1].position.x = Float(currentCoord.x)
            vb[vertexIndex + 1].position.y = Float(currentCoord.y)
            vb[vertexIndex + 1].color = vertexColor
            vb[vertexIndex + 1].direction = -1
            
            vb[vertexIndex + 1].normal.x = Float(leftNorm.x)
            vb[vertexIndex + 1].normal.y = Float(leftNorm.y)
            
            vb[vertexIndex + 1].nextNormal.x = Float(rightNorm.x)
            vb[vertexIndex + 1].nextNormal.y = Float(rightNorm.y)
            
            if !isLast {
                let vertexIndexUInt16 = UInt16(vertexIndex)
                let indexIndex = vertexNumber * 6
                ib[indexIndex + 0] = vertexIndexUInt16
                ib[indexIndex + 1] = vertexIndexUInt16 + 2
                ib[indexIndex + 2] = vertexIndexUInt16 + 3
                ib[indexIndex + 3] = vertexIndexUInt16
                ib[indexIndex + 4] = vertexIndexUInt16 + 3
                ib[indexIndex + 5] = vertexIndexUInt16 + 1;
            }
        }
    }
    
    func render(withEncoder encoder: MTLRenderCommandEncoder, context: MetalContext) {

        guard let chart = self.chart else {
            return
        }
        
        let view = context.view
        
        let indexCount = (chart.points.count - 1) * 6;
        
        let viewPort = context.dimensionsConverter.convertViewPortToDisplayViewPort(context.viewPort)
        var viewportSize = vector_int4.init(Int32(viewPort.x),
                                                      Int32(viewPort.y),
                                                      Int32(viewPort.xEnd),
                                                      Int32(viewPort.yEnd))
        
        let viewSize = view.drawableSize
        var screenSize = vector_int2.init(Int32(viewSize.width), Int32(viewSize.height))
        
        self.updateGeometry(chart, vertexBuffer: self.vertexBuffer, indexBuffer: self.indexBuffer)
                
        encoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: Int(AAPLVertexInputIndexVertices.rawValue))
        encoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_int4>.stride, index: Int(AAPLVertexInputIndexViewportSize.rawValue))
        encoder.setVertexBytes(&screenSize, length: MemoryLayout<vector_int2>.stride, index: Int(AAPLVertexInputIndexScreenSize.rawValue))
        
        encoder.drawIndexedPrimitives(type: .triangle,
                                       indexCount: indexCount,
                                       indexType: .uint16,
                                       indexBuffer: self.indexBuffer,
                                       indexBufferOffset:0)
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
        
        guard numVertices > 3 else {
            print("too few vertices in buffer, skip draw (\(numVertices))")
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
        
//        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index:Int(AAPLVertexInputIndexVertices.rawValue))
//
//        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: Int(AAPLVertexInputIndexViewportSize.rawValue))
//        // Draw the vertices of the quads
//        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: numVertices)
        
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
        
        var colorVector = vector_float4(0.0, 0.0, 0.0, 1.0) // black
        if let color = color, let components = color.cgColor.components {
            if components.count <= 2 {
                let gray = Float(components[0])
                colorVector[0] = gray
                colorVector[1] = gray
                colorVector[2] = gray
            } else if components.count >= 3 {
                colorVector[0] = Float(components[0])
                colorVector[1] = Float(components[1])
                colorVector[2] = Float(components[2])
            }
        }
        
        var chartContext = ChartContext(viewportSize: viewportSize, screenSize: screenSize, color: colorVector, lineWidth:lineWidth)

        encoder.setVertexBuffer(vertexBuffer, offset: 0,
                                index: Int(AAPLVertexInputIndexVertices.rawValue))
//        encoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_int4>.stride,
//                               index: Int(AAPLVertexInputIndexViewportSize.rawValue))
//        encoder.setVertexBytes(&screenSize, length: MemoryLayout<vector_int2>.stride,
//                               index: Int(AAPLVertexInputIndexScreenSize.rawValue))
        
        encoder.setVertexBytes(&chartContext, length: MemoryLayout<ChartContext>.stride,
                               index: Int(AAPLVertexInputIndexChartContext.rawValue))

        
        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: indexCount,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset:0)
        
    }
    

}
