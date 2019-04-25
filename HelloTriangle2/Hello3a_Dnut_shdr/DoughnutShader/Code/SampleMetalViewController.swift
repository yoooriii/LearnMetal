//
//  ViewController.swift
//  MetalTemplate
//
//  Created by Leonid Lokhmatov on 4/19/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

protocol InfoDelegate {
    func setInfo(text:String?)
}

class SampleMetalViewController: UIViewController {
    
    @IBOutlet var infoLabel: UILabel!
    @IBOutlet var mtkView: MTKView!
    var renderer:BasicMetalRenderer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderer = BasicMetalRenderer(mtkView: mtkView)
        renderer?.infoDelegate = self
    }
}

extension SampleMetalViewController: InfoDelegate {
    func setInfo(text:String?) {
        infoLabel.text = text
    }
}
