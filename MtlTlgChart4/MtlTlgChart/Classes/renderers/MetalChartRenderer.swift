//
//  MetalChartRenderer.swift
//  GraphPresenter
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import Foundation
import MetalKit

class MetalChartRenderer: NSObject {
    var graph: GraphData? = nil
    var alpha: CGFloat = 1.0
    private var chart: ChartData?
    
    private let mtkView:MTKView!
    private let metalContext:ZMetalContext!
    // absolute coordinates in graph values
    var commonGraphRect = vector_float4(1)
    
    var pointsCount = 0
    var vertexCount:Int { get { return pointsCount * 2 } }
    var strokeColor:UIColor?
    var lineWidth = Float(2) {
        didSet { mtkView.setNeedsDisplay() }
    }

    var planeRenderers = [GraphRendererProto]()
    private var gridRenderer:GridRenderer?
    private var plane:Plane?
    var graphMode:VShaderMode = VShaderModeStroke
    private var msaaTexture: MTLTexture?

    //MARK: -
    
    init(mtkView: MTKView, metalContext:ZMetalContext) {
        self.mtkView = mtkView
        self.metalContext = metalContext
        super.init()
        metalContext.setupMetalView(mtkView)
        mtkView.delegate = self
        self.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
    }
    
    /// switch to another palne
    func setPlane(_ plane:Plane) {
        mtkView.setNeedsDisplay()
        self.plane = plane
        let countP = plane.vAmplitudes.count
        planeRenderers.removeAll()
        
        if let _ = gridRenderer {} else {
            gridRenderer = GridRenderer(device: metalContext.device)
        }
        let grSize = mtkView.drawableSize
        gridRenderer!.setViewSize(viewSize: int2(Int32(grSize.width), Int32(grSize.height)))
        planeRenderers.append(gridRenderer!)

        var graphRect = vector_float4(0)
        for iPlane in 0 ..< countP {
            let pRenderer = GraphRenderer(device: metalContext.device)
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
    
    func setFillMode(_ fillMode:Bool) {
        mtkView.setNeedsDisplay()
        graphMode = fillMode ? VShaderModeFill : VShaderModeStroke
        for render in planeRenderers {
            if let graphRender = render as? GraphRenderer {
                graphRender.graphMode = graphMode
            }
        }
    }
}


extension MetalChartRenderer: MTKViewDelegate {
    /// Called whenever view changes orientation or is resized
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // reset cached texture, it will be recreated on a next draw pass
        msaaTexture = nil
        
        if let gridRenderer = self.gridRenderer {
            gridRenderer.setViewSize(viewSize: int2(Int32(size.width), Int32(size.height)))
        }
    }
    
    func draw(in view: MTKView) {
        let renderPassDescriptor = makeRenderPassDescriptor(view: view)
        metalContext.draw(in: view, renderPassDescriptor:renderPassDescriptor) { renderEncoder in
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
        }
    }
}


private extension MetalChartRenderer {
    private func makeMSAATexture(size:vector_int2) -> MTLTexture? {
        let desc = MTLTextureDescriptor()
        desc.textureType = MTLTextureType.type2DMultisample
        desc.width = Int(size.x)
        desc.height = Int(size.y)
        desc.sampleCount = 4
        desc.pixelFormat = .bgra8Unorm
        desc.usage = MTLTextureUsage.renderTarget // it fixes crash under xcode debugger
        desc.storageMode = .memoryless
        
        return metalContext.device.makeTexture(descriptor: desc)
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
        rPassDescriptor.colorAttachments[0].clearColor = view.clearColor //MTLClearColor(red: 0.1, green: 0.4, blue: 0.5, alpha: 0.0)
        rPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        
        return rPassDescriptor
    }
}
