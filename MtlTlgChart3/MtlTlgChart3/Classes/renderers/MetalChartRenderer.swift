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
    var commonGraphRect = vector_float4(1)
    // view.drawableSize (no need to keep it here)
    var screenSize = vector_int2(1)
    
    var pointsCount = 0
    var vertexCount:Int { get { return pointsCount * 2 } }
    var strokeColor:UIColor?
    var lineWidth = Float(10)//Float(1.5)

    ///////////////////
    var planeRenderers = [GraphRendererProto]()
    private var gridRenderer:GridRenderer!
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device
    init(mtkView: MTKView) {
        device = mtkView.device
        super.init()
        loadMetal(mtkView: mtkView)
    }
    
    private var plane:Plane? = nil
    
    /// switch to another palne
    func setPlane(_ plane:Plane) {
        self.plane = plane
        let countP = plane.vAmplitudes.count
        planeRenderers.removeAll()
        
        if let _ = gridRenderer {} else {
            gridRenderer = GridRenderer(device: device)
        }
        planeRenderers.append(gridRenderer)

        var graphRect = vector_float4(0)
        for iPlane in 0 ..< countP {
            let pRenderer = GraphRenderer(device: device)
            pRenderer.setPlane(plane, iPlane: iPlane)
            pRenderer.graphMode = VShaderModeFill
            planeRenderers.append(pRenderer)    

            if 0 == iPlane {
                // take the first rect
                graphRect = pRenderer.graphRect
            } else {
                // compare with other rects and get extremums
                let nextGraphRect = pRenderer.graphRect
                if graphRect[0] > nextGraphRect[0] { graphRect[0] = nextGraphRect[0] }
                if graphRect[1] > nextGraphRect[1] { graphRect[1] = nextGraphRect[1] }
                if graphRect[2] < nextGraphRect[2] { graphRect[2] = nextGraphRect[2] }
                if graphRect[3] < nextGraphRect[3] { graphRect[3] = nextGraphRect[3] }
            }
        }
        commonGraphRect = graphRect
        
        for pRenderer in planeRenderers {
            pRenderer.loadResources()
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
        }

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Pipeline"

        if let defaultLibrary = device.makeDefaultLibrary() {
            pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertexShader")
            pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragmentShader")
//            let bbb = defaultLibrary.makeFunction(name: "vertexShaderFilled")
        }
        

        mtkView.sampleCount = 4 // default=1
        mtkView.colorPixelFormat = .bgra8Unorm
        pipelineStateDescriptor.sampleCount = mtkView.sampleCount
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineStateDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat

//        if let renderAttachment = pipelineStateDescriptor.colorAttachments[0] {
//            renderAttachment.isBlendingEnabled = true
//            renderAttachment.alphaBlendOperation = .add
//            renderAttachment.rgbBlendOperation = .add
//            renderAttachment.sourceRGBBlendFactor = .sourceAlpha
//            renderAttachment.sourceAlphaBlendFactor = .sourceAlpha
//            renderAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
//            renderAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
//        }

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
    
    private var msaaTexture: MTLTexture?
    
    private func makeTexture(size:vector_int2) -> MTLTexture? {
        let desc = MTLTextureDescriptor()
        desc.textureType = MTLTextureType.type2DMultisample
        desc.width = Int(size.x)
        desc.height = Int(size.y)
        desc.sampleCount = 4
        desc.pixelFormat = .bgra8Unorm
        desc.usage = MTLTextureUsage.renderTarget // it fixes crash under xcode debugger

        return device.makeTexture(descriptor: desc)
    }
}

extension MetalChartRenderer: MTKViewDelegate {
    /// Called whenever view changes orientation or is resized
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Save the size of the drawable as we'll pass these
        //   values to our vertex shader when we draw
        screenSize.x = Int32(size.width)
        screenSize.y = Int32(size.height)
        // recreate texture to fit the size
        msaaTexture = makeTexture(size: screenSize)
    }
    
    func draw(in view: MTKView) {
        guard !planeRenderers.isEmpty else {
//            print("empty renders array")
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("cannot create command buffer")
            return
        }
        commandBuffer.label = "MyCommandBuffer"
        
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
            return
        }
        renderEncoder.label = "MyRenderEncoder"

        //TODO: maybe use the viewport
//        let viewport = MTLViewport(originX: -1, originY: -1,
//                                   width: 2, height: 2,
//                                   znear: -1, zfar: 1)
//        // Set the region of the drawable to which we'll draw.
//        renderEncoder.setViewport(viewport)

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setCullMode(.none)

        //encodeGraph(encoder: renderEncoder, view: view, color: strokeColor)
        for i in 0 ..< planeRenderers.count {
            var pRenderer = planeRenderers[i]
            pRenderer.lineWidth = lineWidth
            pRenderer.graphRect = commonGraphRect
            pRenderer.encodeGraph(encoder: renderEncoder, view: view)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
