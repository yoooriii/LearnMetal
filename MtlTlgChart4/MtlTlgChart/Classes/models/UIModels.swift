//
//  UIModels.swift
//  TelegramChart
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit

class VectorRange: NSObject {
    var position: Double
    var length: Double

    var endPosition: Double {
        get { return position + length }
    }

    convenience init(position: CGFloat, length: CGFloat) {
        self.init(position: Double(position), length: Double(length))
    }

    init(position: Double, length: Double) {
        self.position = position
        self.length = length
    }
}


/// plane model, keeps one x and one y vectors
struct Plane2d {
    let vTime: VectorTime!
    let vAmplitude: VectorAmplitude!
    var color: UIColor?
    var bounds: CGRect?
    var path: CGPath?

    init(vTime:VectorTime!, vAmplitude: VectorAmplitude!) {
        self.vTime = vTime
        self.vAmplitude = vAmplitude
    }
}

/// just a container for Plane2d objects
struct Plane3d {
    let planes:[Plane2d]!
}

extension Plane2d {
    func pathInRect(_ bounds:CGRect) -> CGPath {
        let plane2d = self
        // translations
        let tx:CGFloat = -CGFloat(plane2d.vTime.minValue)
        let ty:CGFloat = -CGFloat(plane2d.vAmplitude.minValue)
        // scales
        let dx = CGFloat(plane2d.vTime.maxValue - plane2d.vTime.minValue)
        let dy = CGFloat(plane2d.vAmplitude.maxValue - plane2d.vAmplitude.minValue)
        let sx:CGFloat = dx/bounds.width
        let sy:CGFloat = dy/bounds.height

        let tSize = plane2d.vTime.values.count
        let aSize = plane2d.vAmplitude.values.count
        // !! both sizes must be equal, using min just in case
        let count = min(tSize, aSize)
        let path = CGMutablePath()

        for i in 0..<count {
            let x0 = CGFloat(plane2d.vTime.values[i])
            let y0 = CGFloat(plane2d.vAmplitude.values[i])
            let x = (x0 + tx) / sx
            let y = (y0 + ty) / sy // notice: y is up side down on ios (layer.isGeometryFlipped = true)
            let pt = CGPoint(x:x + bounds.minX, y:y + bounds.minY)
            if 0 == i { path.move(to: pt) } else { path.addLine(to: pt) }
        }

        return path
    }
}
