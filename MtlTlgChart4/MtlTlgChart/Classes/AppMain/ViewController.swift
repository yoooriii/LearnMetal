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

    private var renderer: ZMultiGraphRenderer!  // large view
    private var renderer2: ZMultiGraphRenderer! // small scroll view
    var graphicsContainer:GraphicsContainer?
    
    private var position2d = float2(0.0, 0.2)
    private var heightScale = float2(0, 1)
    
    private var graphViewController:ZGraphController!
    
    //MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        resetSwitches()
        planeSwitches.sort { (swL, swR) -> Bool in
            return swL.tag > swR.tag
        }
//        setActivePlane(nil)
        
        
        if let cx = ZGraphAppDelegate.getMetalContext() {
            renderer = ZMultiGraphRenderer(mtkView:mtkView, metalContext: cx)
            renderer.lineWidth = 4//4
            renderer.isGridEnabled = true
            renderer.isMarkersEnabled = true
            // scroll slider bg renderer
            renderer2 = ZMultiGraphRenderer(mtkView:mtkView2, metalContext: cx)
            renderer2.lineWidth = 2
            renderer2.isGridEnabled = false
            renderer2.isMarkersEnabled = false
            
            graphViewController = ZGraphController(renderer:renderer)
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
                setActivePlane(plane)
                nextPlane += 1
            }
        } else {
            startLoadingData()
        }
    }
    
    @IBAction func actSetHeight(_ slider: UISlider) {
        heightScale.w = 0.5 + (1.0 - slider.value)
        applyPosition()

//        renderer.lineWidth = 3 + (10.0 * slider.value)
    }
    @IBAction func actSetHeight2(_ slider: UISlider) {
        heightScale.x = slider.value * 0.5
        applyPosition()
        
        print("heightScale:\(heightScale)")
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
                    } catch (let eee) {
                        err = NSError("cannot decode json \(eee.localizedDescription)")
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

    func setActivePlane(_ plane:Plane) {
        graphViewController.setPlane(plane)

        renderer2.setPlane(plane)
        setFillMode()
        applyPosition()
        updateSwitches(plane: plane)
        infoLabel.text = "#\(nextPlane): " + plane.info()
    }
    
    private func dbgTestIndices() {
        let vals:[Float] = [-1, -0.1, 0, 0.1, 0.2, 0.5, 0.9, 1.0, 1.05, 1.1, 100]
        var ii = 0
        for v in vals {
            if let ind = renderer.findIndices(normalizedX: v) {
                print("#\(ii): " + String(format: "%2.2f -> [%d, %d]", v, ind.location, ind.length))
            } else {
                print("#\(ii): <nil>")
            }
            ii += 1
        }
    }
    
    private func resetSwitches() {
        fillModeSwitch.isOn = false
        for sw in planeSwitches {
            sw.isOn = false
            sw.isHidden = true
        }
    }
    
    private func updateSwitches(plane:Plane) {
        let ampCount = Int(plane.vAmplitudes.count)
        let count = max(ampCount, planeSwitches.count)
        for i in 0 ..< count {
            if (i < planeSwitches.count) {
                let sw = planeSwitches[i]
                if (i < ampCount) {
                    let amp = plane.vAmplitudes[i]
                    sw.isHidden = false
                    sw.isOn = true
                    sw.tintColor = amp.color
                    sw.onTintColor = amp.color
                } else {
                    sw.isHidden = true
                    sw.isOn = false
                }
            }
        }
    }

    private func setFillMode() {
        renderer.setFillMode(fillModeSwitch.isOn)
        renderer2.setFillMode(fillModeSwitch.isOn)
    }    

    private func applyPosition() {
        renderer.heightScale = heightScale
        graphViewController.position2d = position2d
    }
}

extension ViewController: ZScrollSlider2dDelegate {
    func scrollSlider(_ slider:ZScrollSlider2d, positionDidChange pos2d:float2) {
        position2d = pos2d
        applyPosition()
    }
}

extension ViewController: ZOvelayInfoViewDelegate {
    func overlayInfo(_ overlay:ZOvelayInfoView, didChange position: Float) {
        let realPosition = position2d.x + position2d.w * position
        renderer.arrowOffsetInVisibleRect = position // it depends on the visible rect
        var info = String(format: "%2.1f", 100.0 * realPosition)
        if let ind2 = renderer.getArrowIndices() {
            info += ":[\(ind2.location):\(ind2.length)]"
        }
        overlay.setInfo(text: info)
    }
}
