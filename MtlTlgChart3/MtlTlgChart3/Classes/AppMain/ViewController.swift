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
    @IBOutlet var infoLabel:UILabel!
    private var renderer: MetalChartRenderer!
    var graphicsContainer:GraphicsContainer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view to use the default device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        
        mtkView.device = device
        renderer = MetalChartRenderer(mtkView:mtkView)

        // Initialize our renderer with the view size
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        mtkView.delegate = renderer
        
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
                infoLabel.text = "#\(nextPlane): " + plane.info()
                nextPlane += 1
            }
        } else {
            startLoadingData()
        }
    }

    @IBAction func acrLineWidth(_ slider: UISlider) {
        renderer.lineWidth = 1.0 + 10.0 * slider.value
    }
    
    @IBAction func switchMode(_ sw: UISwitch) {
        renderer.switchMode(sw.isOn)
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
}
