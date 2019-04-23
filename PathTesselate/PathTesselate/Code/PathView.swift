//
//  PathView.swift
//  PathTesselate
//
//  Created by Leonid Lokhmatov on 4/21/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit

class PathView: UIView {
    lazy var shapeLayer: CAShapeLayer! = {
        return self.layer as! CAShapeLayer
    }()
    
    static override var layerClass:AnyClass {
        get { return CAShapeLayer.self }
    }
    
    func setPath(_ path:CGPath) {
        shapeLayer.path = path
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 1.5
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
    }
}
