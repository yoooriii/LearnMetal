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
    let mtkView:MTKView!
    var pipelineState: MTLRenderPipelineState?
    var commandQueue: MTLCommandQueue!
    // absolute coordinates in graph values
    var commonGraphRect = vector_float4(1)
    
    var pointsCount = 0
    var vertexCount:Int { get { return pointsCount * 2 } }
    var strokeColor:UIColor?
    var lineWidth = Float(2)//Float(1.5)

    ///////////////////
    var planeRenderers = [GraphRendererProto]()
    private var gridRenderer:GridRenderer?
    
    /// Initialize with the MetalKit view from which we'll obtain our Metal device
    init(mtkView: MTKView) {
        self.mtkView = mtkView
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
        let grSize = mtkView.drawableSize
        gridRenderer!.loadContent(viewSize: uint2(UInt32(grSize.width), UInt32(grSize.height)))
        planeRenderers.append(gridRenderer!)

        var graphRect = vector_float4(0)
        for iPlane in 0 ..< countP {
            let pRenderer = GraphRenderer(device: device)
            pRenderer.setPlane(plane, iPlane: iPlane)
            pRenderer.graphMode = graphMode
            planeRenderers.append(pRenderer)    

            if 0 == iPlane {
                // take the first rect
                graphRect = pRenderer.getOriginalGraphRect()
            } else {
                // compare with other rects and get extremums
                let nextGraphRect = pRenderer.getOriginalGraphRect()
                if graphRect[0] > nextGraphRect[0] { graphRect[0] = nextGraphRect[0] }
                if graphRect[1] > nextGraphRect[1] { graphRect[1] = nextGraphRect[1] }
                if graphRect[2] < nextGraphRect[2] { graphRect[2] = nextGraphRect[2] }
                if graphRect[3] < nextGraphRect[3] { graphRect[3] = nextGraphRect[3] }
            }
        }
        commonGraphRect = graphRect
    }
    
    var graphMode:VShaderMode = VShaderModeStroke

    func switchMode(_ state:Bool) {
        graphMode = state ? VShaderModeStroke : VShaderModeFill
        for render in planeRenderers {
            if let graphRender = render as? GraphRenderer {
                graphRender.graphMode = graphMode
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
        }

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Simple Pipeline"

        if let defaultLibrary = device.makeDefaultLibrary() {
            pipelineStateDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertexShader")
            pipelineStateDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragmentShader")
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

        // make pipelineState async (dont block main thread)
        device.makeRenderPipelineState(descriptor: pipelineStateDescriptor) { (pipelineState, error) in
            self.pipelineState = pipelineState
            if let error = error {
                // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
                //  If the Metal API validation is enabled, we can find out more information about what
                //  went wrong.  (Metal API validation is enabled by default when a debug build is run
                //  from Xcode)
                print("Failed to created pipeline state, error \(error.localizedDescription)")
            } else {
                self.commandQueue = device.makeCommandQueue()
            }
        }

//        do {  // make pipelineState sync, blocking method
//            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
//        } catch {
//            // Pipeline State creation could fail if we haven't properly set up our pipeline descriptor.
//            //  If the Metal API validation is enabled, we can find out more information about what
//            //  went wrong.  (Metal API validation is enabled by default when a debug build is run
//            //  from Xcode)
//            print("Failed to created pipeline state, error \(error.localizedDescription)")
//        }
//        commandQueue = device.makeCommandQueue()
    }
    
//    private var renderPassDescriptor: MTLRenderPassDescriptor?
    private var msaaTexture: MTLTexture?
    
    private func makeMSAATexture(size:vector_int2) -> MTLTexture? {
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
    
    private func makeRenderPassDescriptor(view: MTKView) -> MTLRenderPassDescriptor? {
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

extension MetalChartRenderer: MTKViewDelegate {
    /// Called whenever view changes orientation or is resized
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // reset cached texture, it will be recreated on a next draw pass
        msaaTexture = nil
        
        if let gridRenderer = self.gridRenderer {
            gridRenderer.loadContent(viewSize: uint2(UInt32(size.width), UInt32(size.height)))
        }
    }
    
    func draw(in view: MTKView) {
        guard let pipelineState = self.pipelineState else {
            return
        }
        
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
        
        guard let renderPassDescriptor = makeRenderPassDescriptor(view: view) else {
            print("no renderPassDescriptor")
            return
        }
        
        renderPassDescriptor.colorAttachments[0].resolveTexture = currentDrawable.texture

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("cannot make render encoder")
            return
        }
        renderEncoder.label = "Graph Render Encoder"
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setCullMode(.none)

        //encodeGraph(encoder: renderEncoder, view: view, color: strokeColor)
        for i in 0 ..< planeRenderers.count {
            var pRenderer = planeRenderers[i]
            if let _ = pRenderer as? GraphRenderer {
                // for now we dont resize the grid
                pRenderer.lineWidth = lineWidth
                pRenderer.graphRect = commonGraphRect
            }
            pRenderer.encodeGraph(encoder: renderEncoder, view: view)
        }
        
        renderEncoder.endEncoding()
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
