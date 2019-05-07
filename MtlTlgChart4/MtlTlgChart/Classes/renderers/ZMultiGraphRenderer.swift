//
//  ZMultiGraphRenderer
//  MtlTlgChart3
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit
import MetalKit
import simd

class ZMultiGraphRenderer: NSObject {
    var lineWidth = Float(1) {
        didSet { mtkView.setNeedsDisplay() }
    }
    private var graphMode:VShaderMode = VShaderModeStroke
    
    private let gridRenderer = ZGridRenderer()
    private let mtkView:MTKView!
    private let metalContext:ZMetalContext!
    private var msaaTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    private var verticesCount = Int(0) // verticesCount = (verticesPerInstance-2) * planeCount
    private var verticesPerInstance = Int(0)
    private var planeCount = Int(0)
    private var planeMask = UInt32(0xFF) // bit mask to hide/show a plane
    private var plane:Plane?
    private var commonGraphRect = float4(1)
    private var colors = [float4]()

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
        cleanup()
        mtkView.setNeedsDisplay()

        guard let vTime = plane.vTime else {
            // no time axes
            return
        }
        guard let vAmplitudes = plane.vAmplitudes else {
            // no amplitudes axes
            return
        }
        planeCount = plane.vAmplitudes.count
        if planeCount < 1 {
            // no planes, nothing to draw
            return
        }

        // sanity check and collect min/max values (graph bounding box)
        let timeCount = vTime.count!
        var minCount = timeCount
        var graphRect = float4(0) // minX, minY, maxX, maxY
        graphRect[0] = Float(vTime.minValue/1000)
        graphRect[2] = Float(vTime.maxValue/1000)
        for planeIndex in 0 ..< planeCount {
            let ampCount = vAmplitudes[planeIndex].count!
            if minCount > ampCount {
                print("pt count mismatch \(minCount) vs \(ampCount)") // we should not get here
                minCount = ampCount
            }
            
            let minY = Float(vAmplitudes[planeIndex].minValue)
            let maxY = Float(vAmplitudes[planeIndex].maxValue)
            if 0 == planeIndex {
                graphRect[1] = minY
                graphRect[3] = maxY
            } else {
                if graphRect[1] > minY { graphRect[1] = minY }
                if graphRect[3] < maxY { graphRect[3] = maxY }
            }
            
            let color = vAmplitudes[planeIndex].colorVector
            colors.append(color)
        }
        
        if minCount < 2 {
            // no use to handle less than 2 points
            return
        }
        
        // OK, input data is correct, we can proceed
        commonGraphRect = graphRect
        self.plane = plane
        // [x0, y00, y01, y02, y03,  x1, y10, y11, y12, y13, ... xn, yn0, yn1, yn2, yn3]
        var arrCoordinates = [Float]()
        for index in 0 ..< minCount {
            let x = Float(vTime.values[index]/1000)
            arrCoordinates.append(x)
            for planeIndex in 0 ..< planeCount {
                let y = Float(vAmplitudes[planeIndex].values[index])
                arrCoordinates.append(y)
            }
        }
        verticesPerInstance = minCount + 2
        verticesCount = arrCoordinates.count
        vertexBuffer = metalContext.device.makeBuffer(bytes: arrCoordinates,
                                                      length: MemoryLayout<Float>.stride * verticesCount,
                                                      options: .cpuCacheModeWriteCombined)
    }
    
    func setPlaneMask(_ mask: UInt32) {
        planeMask = mask
        mtkView.setNeedsDisplay()
    }
    
    func setFillMode(_ fillMode:Bool) {
        graphMode = fillMode ? VShaderModeFill : VShaderModeStroke
        mtkView.setNeedsDisplay()
    }
}


extension ZMultiGraphRenderer: MTKViewDelegate {
    /// Called whenever view changes orientation or is resized
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // reset cached texture, it will be recreated on a next draw pass
        msaaTexture = nil
    }
    
    func draw(in view: MTKView) {
        let renderPassDescriptor = makeRenderPassDescriptor(view: view)
        let screenSize = int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        gridRenderer.setViewSize(viewSize:screenSize)
        metalContext.draw(in: view, renderPassDescriptor:renderPassDescriptor) { renderEncoder in
            self.gridRenderer.encodeGraph(encoder: renderEncoder, view: view)
            self.encodeGraph(encoder: renderEncoder, view: view)
        }
    }
}


private extension ZMultiGraphRenderer {
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

    func cleanup() {
        planeMask = 0xFF
        verticesPerInstance = 0
        verticesCount = 0
        planeCount = 0
        colors.removeAll()
        vertexBuffer = nil
        commonGraphRect = float4(0)
    }

    func chartContext(view:MTKView, color:float4) -> ChartContext! {
        let screenSize = int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        return ChartContext.combinedContext(graphRect:commonGraphRect,
                                            screenSize:screenSize,
                                            color:color,
                                            lineWidth:lineWidth,
                                            planeCount:planeCount,
                                            planeMask:planeMask,
                                            vertexCount:verticesPerInstance,
                                            vshaderMode:graphMode)
    }
    
    func visiblePlaneCount() -> Int {
        if planeCount == 0 || planeMask == 0 {
            return 0;
        }
        var mask = planeMask
        var count = 0
        for _ in 0 ..< planeCount {
            if 0 != (mask & 1) {
                count += 1
            }
            mask = mask >> 1
        }
        return count;
    }
    
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        let visibleCount = visiblePlaneCount()
        guard let vertexBuffer = vertexBuffer,
            colors.count != 0,
            verticesPerInstance > 1,
            visibleCount > 0 else { return }
        
        var chartCx = chartContext(view:view, color:float4(1)) // no color
        encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                               index: Int(ZVxShaderBidChartContext.rawValue))
        encoder.setVertexBuffer(vertexBuffer, offset: 0,
                                index: Int(ZVxShaderBidVertices.rawValue))
        encoder.setVertexBytes(colors, length: MemoryLayout<float4>.stride * colors.count,
                               index: Int(ZVxShaderBidColor.rawValue))
        print("visible count = \(visibleCount)")
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: verticesPerInstance * 2, instanceCount:visibleCount)
    }
}
