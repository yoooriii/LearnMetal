//
//  ViewController.swift
//  BasicBuffers_sw
//
//  Created by Leonid Lokhmatov on 4/17/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    @IBOutlet var mtkView: MTKView!
    private var renderer: AAPLRenderer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view to use the default device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        mtkView.device = device
        renderer = AAPLRenderer(mtkView:mtkView)
        
        // Initialize our renderer with the view size
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }
}
