//
//  AppDelegate.swift
//  MtlTlgChart3
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit
import MetalKit

@UIApplicationMain
class ZGraphAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var alertWindow: UIWindow?
    private static var metalContext:ZMetalContext?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let metalDevice = MTLCreateSystemDefaultDevice()
        guard let _ = metalDevice else {
            print("Metal is not supported on this device")
            showAlert(title: "Metal Error", message: "Metal is not supported on this device")
            return true
        }
        
        let metalContext = ZMetalContext(device:metalDevice)
        metalContext.loadMetalIfNeeded()
        ZGraphAppDelegate.metalContext = metalContext

        return true
    }

    func showAlert(title:String, message:String) {
        let rootVC:UIViewController
        if let alWnd = alertWindow {
            if let rvc = alWnd.rootViewController {
                rootVC = rvc
            } else {
                rootVC = UIViewController()
                alWnd.rootViewController = rootVC
            }
        } else {
            let frame:CGRect
            if let mainWnd = window {
                frame = mainWnd.screen.bounds
            } else {
                frame = UIScreen.main.bounds
            }
            let alWnd = UIWindow(frame: frame)
            alertWindow = alWnd
            rootVC = UIViewController()
            alWnd.rootViewController = rootVC
        }
        
        let alertCtr = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertCtr.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler:  { [weak self] action in
            if let alertWnd = self?.alertWindow {
                alertWnd.isHidden = true
                self?.alertWindow = nil
                if let mainWnd = self?.window {
                    mainWnd.makeKeyAndVisible()
                }
            }
        }))
        
        alertWindow?.windowLevel = .alert
        alertWindow?.makeKeyAndVisible()
        rootVC.present(alertCtr, animated: true, completion: nil)
    }
    
    static func getMetalContext() -> ZMetalContext? {
        return metalContext
    }
    

}
