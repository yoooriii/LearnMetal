//
//  PathModels.swift
//  TelegramChart
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import UIKit

class Slice: NSObject {
    var pathModels:[PathModel]!
    var rect:CGRect!
    var indices:Indices?

    init(pathModels:[PathModel]!, rect:CGRect, indices:Indices? = nil) {
        super.init()
        self.pathModels = pathModels
        self.rect = rect
        self.indices = indices
    }
}

struct PathModel {
    let path: CGPath!
    let color: UIColor
    let lineWidth: CGFloat

    let min:Int64
    let max:Int64

    init(path: CGPath!, color: UIColor, lineWidth: CGFloat, min:Int64=0, max:Int64=0) {
        self.path = path
        self.color = color
        self.lineWidth = lineWidth
        self.min = min
        self.max = max
    }
}

struct Indices {
    let start:Int!
    let end: Int!
}
