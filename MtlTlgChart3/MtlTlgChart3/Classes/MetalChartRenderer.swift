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
    var lineWidth = Float(10)//Float(1.5)

    ///////////////////
    var planeRenderers = [PlaneRenderer]()
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device
    init(mtkView: MTKView) {
        device = mtkView.device
        super.init()
        loadMetal(mtkView: mtkView)
    }
    
    private var plane:Plane? = nil
    
    func setPlane(_ plane:Plane) {
        self.plane = plane
        let countP = plane.vAmplitudes.count
        planeRenderers.removeAll()

//        viewportSize = vector_int4(minX, minY, maxX, maxY)
        var viewportSize = vector_int4(0)
        for iPlane in 0 ..< countP {
            let pRenderer = PlaneRenderer(device: device)
            pRenderer.setPlane(plane, iPlane: iPlane)
            if 0 == iPlane {
                viewportSize = pRenderer.viewportSize
            } else {
                let vpSize = pRenderer.viewportSize
                if viewportSize[0] > vpSize[0] { viewportSize[0] = vpSize[0] }
                if viewportSize[1] > vpSize[1] { viewportSize[1] = vpSize[1] }
                if viewportSize[2] < vpSize[2] { viewportSize[2] = vpSize[2] }
                if viewportSize[3] < vpSize[3] { viewportSize[3] = vpSize[3] }
            }
            planeRenderers.append(pRenderer)
        }

        for pRenderer in planeRenderers {
            pRenderer.viewportSize = viewportSize
        }


        return


        let count1 = plane.vTime.count
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

        for iPoint in 0 ..< pointsCount {
            let vx = ChartRenderVertex(position: points[iPoint])
            vertexMemArray[iPoint * 2] = vx
            vertexMemArray[iPoint * 2 + 1] = vx

            let isLast = iPoint >= pointsCount - 1
            if !isLast {
                let ibi = iPoint * 6
                let vertexIndex = UInt16(iPoint * 2)
                indexMemArray[ibi]   = vertexIndex
                indexMemArray[ibi+1] = vertexIndex + 2
                indexMemArray[ibi+2] = vertexIndex + 3
                indexMemArray[ibi+3] = vertexIndex
                indexMemArray[ibi+4] = vertexIndex + 3
                indexMemArray[ibi+5] = vertexIndex + 1
            }
        }
    }

    /// Create our Metal render state objects including our shaders and render state pipeline objects
    private func loadMetal(mtkView: MTKView!) {
        guard let device = self.device else {
            print("no metal device")
            return
        }

        if true {
            mtkView.isOpaque = false
            mtkView.clearColor = MTLClearColor.init(red: 0, green: 0, blue: 0, alpha: 0)
//            mtkView.sampleCount = 4;
        }

        let defaultLibrary = device.makeDefaultLibrary()
        let vertexFunction = defaultLibrary?.makeFunction(name: "vertexShader")
        let fragmentFunction = defaultLibrary?.makeFunction(name: "fragmentShader")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Pipeline"
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction

        mtkView.sampleCount = 1 // default=1
        mtkView.colorPixelFormat = .bgra8Unorm
        pipelineStateDescriptor.sampleCount = mtkView.sampleCount
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineStateDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        if let renderAttachment = pipelineStateDescriptor.colorAttachments[0] {
            renderAttachment.isBlendingEnabled = true
            renderAttachment.alphaBlendOperation = .add
            renderAttachment.rgbBlendOperation = .add
            renderAttachment.sourceRGBBlendFactor = .sourceAlpha
            renderAttachment.sourceAlphaBlendFactor = .sourceAlpha
            renderAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

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
//        guard let vertexBuffer = self.vertexBuffer else {
//            //print("no vertex buffer, skip draw")
//            return
//        }
//
//        guard vertexCount > 2 else {
//            print("too few vertices in buffer, skip draw (\(vertexCount))")
//            return
//        }

        guard !planeRenderers.isEmpty else {
            print("empty renders array")
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

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.5, 0.5, 1.0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
//        renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("cannot make render encoder")
            return
        }
        renderEncoder.label = "MyRenderEncoder"

        //TODO: maybe use it
//        let viewport = MTLViewport(originX: 0, originY: 0,
//                                   width: Double(viewportSize.x), height: Double(viewportSize.y),
//                                   znear: -1, zfar: 1)

//        let viewport = MTLViewport(originX: -1, originY: -1,
//                                   width: 2, height: 2,
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

        //encodeGraph(encoder: renderEncoder, view: view, color: strokeColor)
        for pRenderer in planeRenderers {
            pRenderer.lineWidth = lineWidth
            pRenderer.encodeGraph(encoder: renderEncoder, view: view)
        }
        
        renderEncoder.endEncoding()
        if let currentDrawable = view.currentDrawable {
            commandBuffer.present(currentDrawable)
        } else {
            print("no currentDrawable")
        }
        commandBuffer.commit()
    }

    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView, color:UIColor? = UIColor.black) {
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
