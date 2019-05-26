//
//  ZGraphViewController.swift
//  MtlTlgChart4
//
//  Updated by leonid@leeloo on 5/27/19 ©2019 Horns&Hoofs.®
//

import Foundation
import simd

class ZGraphController {
    private let renderer:ZMultiGraphRenderer!
    private let timelineLabelDataSource:ZTimelineLabelDataSource!
    private var timelineLabelView:ZTimelineLabelView?
    
    var position2d: float2 {
        set {
            timelineLabelDataSource.position2d = newValue
            renderer.position2d = newValue
        }
        get { return renderer.position2d }
    }
    
    init(renderer:ZMultiGraphRenderer) {
        self.renderer = renderer
        timelineLabelDataSource = ZTimelineLabelDataSource()
        timelineLabelDataSource.graphView = renderer
    }

    func setPlane(_ plane:Plane) {
        timelineLabelDataSource.plane = plane
        renderer.setPlane(plane)
    }
}
