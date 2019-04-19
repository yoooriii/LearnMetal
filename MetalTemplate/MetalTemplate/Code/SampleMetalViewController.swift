//
//  ViewController.swift
//  MetalTemplate
//
//  Created by Leonid Lokhmatov on 4/19/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

class SampleMetalViewController: UIViewController {
    
    @IBOutlet var mtkView: MTKView!
    var renderer:BasicMetalRenderer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderer = BasicMetalRenderer(mtkView: mtkView)
    }
}
