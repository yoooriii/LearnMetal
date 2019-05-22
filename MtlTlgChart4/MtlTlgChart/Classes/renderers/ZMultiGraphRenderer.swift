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
    private let defaultLineWidth = Float(2)
    var lineWidth: Float {
        didSet { mtkView.setNeedsDisplay() }
    }
    var lineDashPattern: float2 = float2(15, 5)
    var isGridEnabled = false
    var arrowPointRadius:Float { get { return max(10.0, lineWidth * 2.0) } }
    private var graphMode:VShaderMode = VShaderModeStroke
    
    private let gridRenderer = ZGridRenderer()
    private let mtkView:MTKView!
    private let metalContext:ZMetalContext!
    private var msaaTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    private var pointsCount = Int(0)
    private var planeCount = Int(0)
    private var planeMask = UInt32(0xFF) // bit mask to hide/show a plane
    private var plane:Plane?
    private var instanceDescriptors = [InstanceDescriptor]()
    private var boundingBox = float4() // (x, y, w, h)

    var arrowOffsetInVisibleRect = Float(0) {
        didSet {
            doUpdateArrowPosition()
            mtkView.setNeedsDisplay()
        }
    }

    private var arrowPositionX:Float {
        get { return position2d.x + position2d.w * arrowOffsetInVisibleRect }
    }

    private var arrowIndices:NSRange?

    var position2d: float2 = float2(0, 1) {
        didSet {
            doUpdateArrowPosition()
            mtkView.setNeedsDisplay()
        }
    }
    
    var heightScale: float2 = float2(0, 1) {
        didSet {
            mtkView.setNeedsDisplay()
        }
    }
    
    private var margins:float2 = float2(0.1, 0.1) // normalized margin top & bottom
    
    //MARK: -
    
    init(mtkView: MTKView, metalContext:ZMetalContext) {
        self.mtkView = mtkView
        self.metalContext = metalContext
        lineWidth = defaultLineWidth
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
            let instDescriptor = InstanceDescriptor(color: color, stride:UInt32(planeCount + 1), offsetIY: UInt32(planeIndex + 1))
            instanceDescriptors.append(instDescriptor)
        }
        
        if minCount < 2 {
            // no use to handle less than 2 points
            return
        }
        
        // OK, input data is correct, we can proceed
        boundingBox = float4(graphRect[0], graphRect[1], graphRect[2]-graphRect[0], graphRect[3]-graphRect[1])
        self.plane = plane
        let dx = boundingBox.width / 500.0 // value small enough 
        // [x0, y00, y01, y02, y03,  x1, y10, y11, y12, y13, ... xn, yn0, yn1, yn2, yn3]
        var arrCoordinates = [Float]()
        arrCoordinates.reserveCapacity((minCount + 2) * (planeCount + 1))
        for index in 0 ..< minCount {
            let x = Float(vTime.values[index]/1000)
            // repeat the 1st point -dx
            if 0 == index {
                arrCoordinates.append(x - dx)
                for planeIndex in 0 ..< planeCount {
                    let y = Float(vAmplitudes[planeIndex].values[index])
                    arrCoordinates.append(y)
                }
            }
            
            arrCoordinates.append(x)
            for planeIndex in 0 ..< planeCount {
                let y = Float(vAmplitudes[planeIndex].values[index])
                arrCoordinates.append(y)
            }
            
            // repeat the last point +dx
            if minCount - 1 == index {
                arrCoordinates.append(x + dx)
                for planeIndex in 0 ..< planeCount {
                    let y = Float(vAmplitudes[planeIndex].values[index])
                    arrCoordinates.append(y)
                }
            }
        }
        pointsCount = minCount
        vertexBuffer = metalContext.device.makeBuffer(bytes: arrCoordinates,
                                                      length: MemoryLayout<Float>.stride * arrCoordinates.count,
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

    func getBoundingBox() -> float4 {
        return boundingBox
    }

    func getArrowIndices() -> NSRange? {
        return arrowIndices
    }

    func findIndices(normalizedX:Float) -> NSRange? {
        guard let plane = plane else {
            return nil
        }
        return plane.nearestIndices(normalizedTime: normalizedX)
    }

    func visibleRect() -> float4 {
        // conver bounding box to visible rect using position2d & heightScale
        var visibleRect = boundingBox
        visibleRect.x += visibleRect.width * position2d.x
        visibleRect.width *= position2d.w
        
        // apply margins
//        let heightScale = float2(self.heightScale.x * ,
//                                 self.heightScale.w)

        visibleRect.y -= visibleRect.height * heightScale.x
        visibleRect.height *= heightScale.w
        
        // apply margins
//        visibleRect.y -= margins[0] * visibleRect.height
//        visibleRect.height *= 1.0 - margins[0] - margins[1]
        
        return visibleRect
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
        let drawableSize = int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        gridRenderer.setViewSize(viewSize:drawableSize)
        gridRenderer.boundingBox = boundingBox
        metalContext.draw(in: view, renderPassDescriptor:renderPassDescriptor) { renderEncoder in
//            self.gridRenderer.encodeGraph(encoder: renderEncoder, view: view)
            self.encodeGraph(encoder: renderEncoder, view: view)
        }
    }
}


private extension ZMultiGraphRenderer {
    func makeMSAATexture(size:vector_int2) -> MTLTexture? {
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
    
    func makeRenderPassDescriptor(view: MTKView) -> MTLRenderPassDescriptor? {
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
        pointsCount = 0
        planeCount = 0
        instanceDescriptors.removeAll()
        vertexBuffer = nil
        boundingBox = float4(0)
    }

    func chartContext(view:MTKView, mode:VShaderMode) -> ChartContext! {
        let screenSize = int2(Int32(view.drawableSize.width), Int32(view.drawableSize.height))
        let lineWidth = self.lineWidth * Float(view.contentScaleFactor)
        let ptRadius = arrowPointRadius * Float(view.contentScaleFactor)
        let pointer = ArrowPointer(radius:ptRadius, offsetNX:arrowPositionX, range:arrowIndices)
        
        return ChartContext(visibleRect:visibleRect(),
                            boundingBox: boundingBox,
                            screenSize:screenSize,
                            lineWidth:lineWidth,
                            vertexCount:vertexPerInstanceCount(),
                            vshaderMode:mode,
                            arrowPointer:pointer)
    }
    
    func visibleDrawDescriptors() -> [InstanceDescriptor] {
        var instDescriptors = [InstanceDescriptor]()
        if planeCount != 0 && planeMask != 0 {
            var mask = planeMask
            for i in 0 ..< planeCount {
                if 0 != (mask & 1) {
                    instDescriptors.append(instanceDescriptors[i])
                }
                mask >>= 1
            }
        }
        return instDescriptors
    }
    
    func doUpdateArrowPosition() {
        arrowIndices = findIndices(normalizedX: arrowPositionX)
    }
    
    func vertexPerInstanceCount() -> Int {
        return pointsCount * 2 + 2
    }
    
    func encodeGraph(encoder:MTLRenderCommandEncoder, view: MTKView) {
        let instanceDescriptors = visibleDrawDescriptors()
        guard let vertexBuffer = vertexBuffer,
            instanceDescriptors.count != 0,
            pointsCount > 1
        else { return }
        
        var chartCx = chartContext(view:view, mode: graphMode)! // no color
        encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                               index: Int(ZVxShaderBidChartContext.rawValue))
        encoder.setVertexBuffer(vertexBuffer, offset: 0,
                                index: Int(ZVxShaderBidVertices.rawValue))
        encoder.setVertexBytes(instanceDescriptors, length: MemoryLayout<InstanceDescriptor>.stride * instanceDescriptors.count,
                               index: Int(ZVxShaderBidInstanceDescriptor.rawValue))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexPerInstanceCount(), instanceCount:instanceDescriptors.count)
        
        
        // draw an arrow (circle pointers); it does not use vertices;
        chartCx.setMode(VShaderModeArrow)
        encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                               index: Int(ZVxShaderBidChartContext.rawValue))
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: Int(ArrowCircleVertexCount)*2, instanceCount:instanceDescriptors.count)
        
        if isGridEnabled {
            // draw lines
            let lineDescriptors = makeLineDescriptors()
            if lineDescriptors.count > 0 {
                chartCx.setMode(VShaderModeDash)
                encoder.setVertexBytes(&chartCx, length: MemoryLayout<ChartContext>.stride,
                                       index: Int(ZVxShaderBidChartContext.rawValue))
                encoder.setVertexBytes(lineDescriptors, length: MemoryLayout<LineDescriptor>.stride * lineDescriptors.count,
                                       index: Int(ZVxShaderBidInstanceDescriptor.rawValue))
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount:lineDescriptors.count)
            }
        }
    }
    
    func makeLineDescriptors() -> [LineDescriptor] {
        let color = float4(0.5, 0.5, 0.5, 1)
        let scale = Float(mtkView.contentScaleFactor)
        let pattern = lineDashPattern * scale
        let lineWidth = 1.0 * scale
        
        var lnDescriptors = [LineDescriptor]()
        let stepsY = 10
        let dy = boundingBox.height/Float(stepsY)
        
        for i in 0 ... stepsY {
            let y = boundingBox.y + dy * Float(i)
            let line = LineDescriptor(color: color, isVertical: 0, dashPattern: pattern, lineWidth: lineWidth, offset: y)
            lnDescriptors.append(line)
        }

        let color2 = float4(0.7, 0.7, 0.5, 1)
        let dx = boundingBox.width/30.0
        for x in stride(from: boundingBox.x, to: boundingBox.maxX, by: dx) {
            let line = LineDescriptor(color: color2, isVertical: 1, dashPattern: pattern, lineWidth: lineWidth, offset: x)
            lnDescriptors.append(line)
        }
        let line3 = LineDescriptor(color: color2, isVertical: 1, dashPattern: pattern, lineWidth: lineWidth, offset: boundingBox.maxX)
        lnDescriptors.append(line3)

        return lnDescriptors
    }
    
    // TODO: debug func, no use; remove it when done;
    func makeTestCircularVertices(center: float2, radius:Float, steps:Int) -> [float2] {
        var resVertices = [float2]()
        if steps < 3 {
            print("too few steps \(steps)")
            return resVertices
        }

        let minR = radius / 2.0
        let pi2 = Float.pi * 2.0

        for i in 0 ..< steps * 2 {
            let a = pi2 * Float(i) / Float(steps * 2)
            let r = (i & 1 == 0) ? radius : minR
            let pos = float2(sin(a), cos(a)) * r + center
            resVertices.append(pos)
        }

        // close the path
        resVertices.append(resVertices[0])
        resVertices.append(resVertices[1])

        return resVertices
    }
}
