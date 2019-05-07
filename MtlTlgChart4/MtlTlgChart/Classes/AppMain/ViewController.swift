//
//  ViewController.swift
//  MtlTlgChart3
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    @IBOutlet var mtkView:MTKView!
    @IBOutlet var mtkView2:MTKView!
    @IBOutlet var infoLabel:UILabel!
    @IBOutlet var planeSwitches: [UISwitch]!
    @IBOutlet var fillModeSwitch: UISwitch!

    private var renderer: ZMultiGraphRenderer!
    private var renderer2: ZMultiGraphRenderer!
    var graphicsContainer:GraphicsContainer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        resetSwitches()
        
        if let cx = ZGraphAppDelegate.getMetalContext() {
            renderer = ZMultiGraphRenderer(mtkView:mtkView, metalContext: cx)
            renderer2 = ZMultiGraphRenderer(mtkView:mtkView2, metalContext: cx)
        }

        startLoadingData()
    }
    
    var nextPlane = 0
    @IBAction func setNextPlaneAction(_ sender: AnyObject) {
        if let container = graphicsContainer {
            if nextPlane >= container.planes.count {
                nextPlane = 0
            }
            if nextPlane < container.planes.count {
                let plane = container.planes[nextPlane]
                // let planeCopy = plane.copy(in: NSRange(location: 0, length: 4))
                renderer.setPlane(plane)
                renderer2.setPlane(plane)
                setFillMode()
                updateSwitches(plane: plane)
                infoLabel.text = "#\(nextPlane): " + plane.info()
                nextPlane += 1
            }
        } else {
            startLoadingData()
        }
    }

    @IBAction func acrLineWidth(_ slider: UISlider) {
        renderer.lineWidth = 1.0 + 10.0 * slider.value
        renderer2.lineWidth = 1.0 + 10.0 * slider.value
    }
    
    @IBAction func switchMode(_ sw: UISwitch) {
        setFillMode()
    }
    
    @IBAction func switchPlane(_ sw: UISwitch) {
        var mask = UInt32(0)
        var flag = UInt32(1)
        for sw in planeSwitches {
            if sw.isOn {
                mask |= flag
            }
            flag = flag << 1
        }
        
        print("mask: " + String(format: "0x%02x", mask))
        
        renderer.setPlaneMask(mask)
        renderer2.setPlaneMask(mask)
    }
    
    private func dataDidLoad() {
        print("dataDidLoad")
    }
    
    private func startLoadingData() {
        loadDataInBackground() { [weak self] container, error in
            if let error = error {
                let alert = UIAlertController(title:"Error", message:error.localizedDescription, preferredStyle:.alert)
                alert.addAction(UIAlertAction(title:"Dismiss", style:.cancel, handler: { action in
                    alert.dismiss(animated: true, completion: nil)
                }))
                self?.present(alert, animated:true, completion:nil)
            } else if let container = container {
                self?.graphicsContainer = container
                self?.dataDidLoad()
            } else {
                print("OOPS!! something went really wrong")
            }
        }
    }
    
    private func loadDataInBackground(completion:@escaping (GraphicsContainer?, NSError?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            var err:NSError?
            var graphicsContainer:GraphicsContainer?
            let url = Bundle.main.url(forResource: "chart_data", withExtension: "json")
            if let url = url {
                do {
                    let jsonData = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    do {
                        graphicsContainer = try decoder.decode(GraphicsContainer.self, from: jsonData)
                    } catch {
                        err = NSError("cannot decode json")
                    }
                }
                catch {
                    err = NSError("cannot read file at \(url)")
                }
            } else {
                err = NSError("no json")
            }
            
            DispatchQueue.main.async {
                completion(graphicsContainer, err)
            }
        }
    }

    private func resetSwitches() {
        fillModeSwitch.isOn = false
        for sw in planeSwitches {
            sw.isOn = false
            sw.isHidden = false
        }
    }
    
    private func updateSwitches(plane:Plane) {
        var ampCount = Int(plane.vAmplitudes.count)
        for sw in planeSwitches {
            let isOff = ampCount <= 0
            sw.isHidden = isOff
            sw.isOn = !isOff
            ampCount -= 1
        }
    }

    private func setFillMode() {
        renderer.setFillMode(fillModeSwitch.isOn)
        renderer2.setFillMode(fillModeSwitch.isOn)
    }    
}
