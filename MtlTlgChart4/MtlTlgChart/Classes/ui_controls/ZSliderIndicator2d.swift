//
//  ZSliderIndicator2d.swift
//  SliderExtended
//
//  Created by Leonid Lokhmatov on 5/6/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import simd

class ZSliderIndicator2d: UIView {
    var color = UIColor.green
    var lineWidth = CGFloat(3)
    
    var position2d: float2 = float2(0) {
        didSet { setNeedsDisplay() }
    }
    
    override func draw(_ rect: CGRect) {
        if let cx = UIGraphicsGetCurrentContext() {
            cx.setStrokeColor(color.cgColor)
            cx.addPath(CGPath(rect: bounds, transform: nil))
            cx.setLineWidth(lineWidth)
            cx.strokePath()
            
            let lineWidth2 = lineWidth/2.0
            let contentRect = bounds.insetBy(dx: lineWidth2, dy: lineWidth2)
            var indicatorRect = contentRect
            indicatorRect.origin.x = contentRect.minX + contentRect.width * CGFloat(position2d[0])
            indicatorRect.size.width = contentRect.width * CGFloat(position2d[1])
            cx.setFillColor(color.cgColor)
            cx.fill(indicatorRect)
        }
    }

    override init(frame: CGRect) {
        super.init(frame:frame)
        internalInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        internalInit()
    }
    
    private func internalInit() {
        color = backgroundColor ?? UIColor.green
        backgroundColor = UIColor.clear
    }
}
