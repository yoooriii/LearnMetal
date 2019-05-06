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
    private var graphMode:VShaderMode = VShaderModeStroke2
    
    private let mtkView:MTKView!
    private let metalContext:ZMetalContext!
    private var msaaTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    private var verticesCount = Int(0)
    private var verticesPerInstance = Int(0)
    private var planeCount = Int(0)
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
        // the first and the last points are just a fake
        let dx0 = Float(graphRect[2] - graphRect[0])/Float(timeCount * 2)

        for index in 0 ..< minCount {
            let x0 = Float(vTime.values[index]/1000)
            let repeatCount:Int
            var dx:Float
            if 0 == index {
                repeatCount = 2
                dx = -dx0
            } else if index == (minCount - 1) {
                repeatCount = 2
                dx = 0
            } else {
                repeatCount = 1
                dx = 0
            }
            
            // add a fake vertex at the beginning and at the end
            for _ in 0 ..< repeatCount {
                let x = x0 + dx
                arrCoordinates.append(x)
                for planeIndex in 0 ..< planeCount {
                    let yi = Float(vAmplitudes[planeIndex].values[index])
                    arrCoordinates.append(yi)
                }
                dx += dx0
            }
        }
        verticesPerInstance = minCount + 2
        verticesCount = arrCoordinates.count
        print("Plane has [planes x points]:[\(planeCount) x \(minCount)] ==> \(verticesCount) vertices")

        vertexBuffer = metalContext.device.makeBuffer(bytes: arrCoordinates,
                                                      length: MemoryLayout<Float>.stride * verticesCount,
                                                      options: .cpuCacheModeWriteCombined)
    }
    
    func setFillMode(_ fillMode:Bool) {
        graphMode = fillMode ? VShaderModeFill2 : VShaderModeStroke2
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
        metalContext.draw(in: view, renderPassDescriptor:renderPassDescriptor) { renderEncoder in
            //encodeGraph(encoder: renderEncoder, view: view, color: strokeColor)
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
                                            vertexCount:verticesPerInstance,
                                            vshaderMode:graphMode)
    }
    
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        guard let vertexBuffer = self.vertexBuffer, colors.count != 0 else {
            return
        }
        
        var chartCx = chartContext(view:view, color:float4(1)) // no color
        encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                               index: Int(AAPLVertexInputIndexChartContext.rawValue))
        encoder.setVertexBuffer(vertexBuffer, offset: 0,
                                index: Int(AAPLVertexInputIndexVertices.rawValue))
        encoder.setVertexBytes(colors, length: MemoryLayout<float4>.stride * colors.count,
                               index: Int(AAPLVertexInputIndexColor.rawValue))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: verticesPerInstance * 2, instanceCount:planeCount)
    }
}
