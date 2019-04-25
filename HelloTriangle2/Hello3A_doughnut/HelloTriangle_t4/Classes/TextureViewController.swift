//
//  TextureViewController.swift
//  HelloTriangle2(sw)
//
//  Created by Leonid Lokhmatov on 4/15/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import MetalKit

protocol InfoDelegate {
    func setInfo(text:String)
}

extension TextureViewController: InfoDelegate {
    func setInfo(text:String) {
        infoLabel.text = text
    }
}

class TextureViewController: UIViewController {
    @IBOutlet weak var mtkView:MTKView!
    @IBOutlet weak var infoLabel:UILabel!
    @IBOutlet weak var pinchRecognizer:UIPinchGestureRecognizer!
    @IBOutlet weak var rotationRecognizer:UIRotationGestureRecognizer!
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
            renderer.infoDelegate = self
//            renderer.mtkView(mtkView, drawableSizeWillChange:mtkView.drawableSize)
        } else {
            print("Renderer failed initialization")
        }
        
        rotationRecognizer.shouldRequireFailure(of: pinchRecognizer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // make sure it is needed
        renderer?.mtkView(mtkView, drawableSizeWillChange:mtkView.drawableSize)
    }
    
    private func denormalize(_ val:Float, min:Double, max:Double) -> Double {
        return (max-min) * Double(val) + min
    }
    
    @IBAction func resetPositionAction(_ recognizer: UITapGestureRecognizer) {
        guard let renderer = renderer else { return }

        switch recognizer.state {
        case .ended:
            renderer.setOffset(x:0, y:0)
            
        default: break
        }
    }
    
    @IBAction func actionPinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.scale = 0.7
            break

        case .changed:
            let n = Int(denormalize(Float((recognizer.scale - 0.5)/5.0), min: 3, max: 50))
            renderer?.setVertSteps(steps: n)
            break
            
        default: break
        }
    }
    
    @IBAction func panActRecognized(_ recognizer: UIPanGestureRecognizer) {
        guard let renderer = renderer else { return }
        
        let scale = mtkView.contentScaleFactor

        switch recognizer.state {
        case .ended, .cancelled:
            break
            
        case .began:
            let pt0 = renderer.getOffset()
            let pt1 = CGPoint(x: pt0.x/scale, y: pt0.y/scale)
            recognizer.setTranslation(pt1, in: mtkView)
            break
            
        case .changed:
            let pos = recognizer.translation(in: mtkView)
            offsetX = Double(pos.x * scale)
            offsetY = Double(pos.y * scale)
            renderer.setOffset(x:offsetX, y:offsetY)
            break
            
        default:
            break
        }
    }
    
    @IBAction func testSliderValueAction(_ slider: UISlider) {
        let rotation = denormalize(slider.value, min: 0, max: .pi * 2.0)
        renderer?.setRotation(Float(rotation))
    }
    
    @IBAction func actionRotate(_ recognizer: UIRotationGestureRecognizer) {
        renderer?.setRotation(Float(recognizer.rotation))
        
        switch recognizer.state {
        case .possible:
            recognizer.require(toFail: pinchRecognizer)
            break
        default:
            break
        }
    }
}
