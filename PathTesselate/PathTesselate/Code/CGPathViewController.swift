//
//  ViewController.swift
//  MetalTemplate
//
//  Created by Leonid Lokhmatov on 4/19/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

class CGPathViewController: UIViewController {
    
    @IBOutlet var mtkView: MTKView!
    @IBOutlet var pathView:PathView!
    var renderer:BasicMetalRenderer?
    var contentProvider:PathMetalRenderer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderer = BasicMetalRenderer(mtkView: mtkView)
        contentProvider = PathMetalRenderer(device:renderer?.device)
        renderer?.contentProvider = contentProvider
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let rect = CGRect(x: 50, y: 50, width: 300, height: 100)
        
        let p = TestPathMath.createTestPath(in: rect)
        let path3:CGPath = p.takeRetainedValue()
        
        let path = CGPath(rect: rect, transform:nil)
        
        var lineWidth = CGFloat(20)
        let path2 = path.copy(strokingWithWidth:lineWidth, lineCap:.round, lineJoin:.round, miterLimit:lineWidth)
        //path.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: lineWidth)
        
//        let path3 = CGPath(rect: CGRect(x:10, y:10, width:100, height:50), transform:nil)
//        print("my path = \(String.init(describing: path3))")

//        contentProvider?.runTest()
        
        // just in case, it is not needed
        renderer?.mtkView(mtkView, drawableSizeWillChange:mtkView.drawableSize)


        let path4 = path3.copy(strokingWithWidth:lineWidth, lineCap:.round, lineJoin:.round, miterLimit:lineWidth)
        lineWidth = 2
        let path5 = path4.copy(strokingWithWidth:lineWidth, lineCap:.round, lineJoin:.round, miterLimit:lineWidth)

        setPath(path4)
    }
    
    func setPath(_ path: CGPath) {
        pathView.setPath(path)
        contentProvider?.setPath(path)
    }
    

}
