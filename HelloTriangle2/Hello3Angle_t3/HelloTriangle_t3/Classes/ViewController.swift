//
//  ViewController.swift
//  HelloTriangle2(sw)
//
//  Created by Leonid Lokhmatov on 4/15/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    @IBOutlet weak var mtkView:MTKView!
    private var renderer:AAPLRenderer?
    private var offsetX = Double(0)
    private var offsetY = Double(0)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        mtkView.device = device
        
        if let renderer = AAPLRenderer(metalKitView:mtkView)  {
            // Initialize our renderer with the view size
            self.renderer = renderer
            mtkView.delegate = renderer
//            renderer.mtkView(mtkView, drawableSizeWillChange:mtkView.drawableSize)
        } else {
            print("Renderer failed initialization")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // make sure it is needed
        renderer?.mtkView(mtkView, drawableSizeWillChange:mtkView.drawableSize)
    }
    
    private func denormalize(_ val:Float, min:Double, max:Double) -> Double {
        return (max-min) * Double(val) + min
    }
    
    @IBAction func actionChangeX(_ sender: UISlider) {
        let w = Double(mtkView.drawableSize.width)
        offsetX = denormalize(sender.value, min: -w, max: w)
        renderer?.setOffset(x:offsetX, y:offsetY)
    }
    
    @IBAction func actionChangeY(_ sender: UISlider) {
//        let h = Double(mtkView.drawableSize.height)
//        offsetY = denormalize(sender.value, min: -h, max: h)
//        renderer?.setOffset(x:offsetX, y:offsetY)
        
        let n = Int(denormalize(sender.value, min: 3, max: 50))
        renderer?.setVertSteps(steps: n)
    }
}
