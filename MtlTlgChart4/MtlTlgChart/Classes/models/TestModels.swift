//
//  TestModels.swift
//  TelegramChart
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit

class TestModels {
    static func pathCircle(SIDE:CGFloat = 256.0) -> CGPath {
        let iCount = 10
        let SIDE2 = SIDE/2.0
        let R = SIDE * 0.2
        let itemRadius = SIDE * 0.28
        let path = CGMutablePath()
        let ovalRect = CGRect(x:SIDE2-itemRadius, y:SIDE2-itemRadius, width:2.0*itemRadius, height:2.0*itemRadius)
        let path0 = CGPath(ellipseIn: ovalRect, transform: nil)
        if true {
            path.addPath(path0)
            path.move(to: CGPoint.zero)
            path.addLine(to: CGPoint(x:SIDE, y:SIDE))
            path.move(to: CGPoint(x:0, y:SIDE))
            path.addLine(to: CGPoint(x:SIDE, y:0))
        }

        for ia in 0..<iCount {
            let angle = 2.0 * Float.pi * Float(ia) / Float(iCount)
            let t1 = R * CGFloat(sinf(angle))
            let t2 = R * CGFloat(cosf(angle))
            let transform = CGAffineTransform(translationX:t1, y:t2)
            path.addPath(path0, transform: transform)
        }
        print("box: \(path.boundingBox)")
        return path
    }
}
