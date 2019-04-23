/// Copyright (c) 2018 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Metal


class ViewController: UIViewController {
  var vertexData:[Float] =
    [0.0, 1.0, 0.0,
     -1.0, -1.0, 0.0,
     1.0, -1.0, 0.0]
  
  var device: MTLDevice!
  var metalLayer: CAMetalLayer!
  var vertexBuffer: MTLBuffer!
  var pipelineState: MTLRenderPipelineState!
  var commandQueue: MTLCommandQueue!
  var timer: CADisplayLink!

  func createWave() {
    vertexData = [Float]()
    let xyz:[Float] = [0.0, 0.0, 0.0]
    vertexData.append(contentsOf: xyz)

    var x = Float(-1.0)
    let dx = Float(0.15)
    let amp = Float(0.95)
    let k = Float(8.0)
    while x < 2.0 {
      let y = sin(x * k) * amp
      x += dx
      let xyz:[Float] = [x, y, 0.0]
      vertexData.append(contentsOf: xyz)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.lightGray
    createWave()
    
    device = MTLCreateSystemDefaultDevice()
    
    metalLayer = CAMetalLayer()          // 1
    metalLayer.device = device           // 2
    metalLayer.pixelFormat = .bgra8Unorm // 3
    metalLayer.framebufferOnly = true    // 4
    var rect = view.layer.bounds
    rect.size.height -= 100.0
    metalLayer.frame = rect  // 5
    view.layer.addSublayer(metalLayer)   // 6
    
    let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0]) // 1
    vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: []) // 2
    
    // 1
    let defaultLibrary = device.makeDefaultLibrary()!
    let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
    let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")
    
    // 2
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction = vertexProgram
    pipelineStateDescriptor.fragmentFunction = fragmentProgram
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    
    // 3
    pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    
    commandQueue = device.makeCommandQueue()
    
    timer = CADisplayLink(target: self, selector: #selector(gameloop))
    timer.add(to: RunLoop.main, forMode: .default)
  }
  
  func render() {
    if 1 == 0 {
      vertexData.append(vertexData[0])
      vertexData.append(vertexData[1])
      vertexData.append(vertexData[2])
      vertexData.remove(at: 0)
      vertexData.remove(at: 0)
      vertexData.remove(at: 0)
      let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0]) // 1
      vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: []) // 2
    }


    guard let drawable = metalLayer?.nextDrawable() else { return }
    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.3, blue: 0.4, alpha: 1.0)
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexData.count/3, instanceCount: 1)
    renderEncoder.endEncoding()
    
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
  @objc func gameloop() {
    autoreleasepool {
      self.render()
    }
  }
}
