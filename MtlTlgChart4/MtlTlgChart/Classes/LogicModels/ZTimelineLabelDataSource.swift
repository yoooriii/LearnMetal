//
//  ZTimelineLabelDataSource.swift
//  MtlTlgChart4
//
//  Updated by leonid@leeloo on 5/27/19 ©2019 Horns&Hoofs.®
//

import Foundation
import simd

protocol GraphViewProtocol: class, NSObjectProtocol {
    func setVerticalLineIndices(_ indices:[Int]?)
    // graph view width in points
    func getWidth() -> Float
}

class ZTimelineLabelDataSource: NSObject {
    let StepWidth = 80 // 1 step width in points
    weak var graphView: GraphViewProtocol?
    let pointsPerStep = Hysteresis(initialValue: 0, hysteresis: 0.1)
    private var pointsCount:Int = 0
    var position2d: float2 = float2(0, 1) {
        didSet {
            cachedIndices = makeIndices()
            graphView?.setVerticalLineIndices(cachedIndices)
        }
    }
    private(set) var cachedIndices:[Int]?
    
    override init() {
        super.init()
        pointsPerStep.valueChangeBlock = { (fromVal:Int, toVal:Int) in print("switch \(fromVal) --> \(toVal)") }
    }
    
    private func cleanup() {
        pointsCount = 0
        cachedIndices = nil
    }
    
    var plane:Plane? {
        didSet {
            cleanup()
            doUpdateContent()
        }
    }
    
    func timeInterval(at index:Int) -> CFTimeInterval? {
        guard let plane = plane else {
            return nil
        }
        if index < 0 || index >= plane.vTime.count {
            return nil
        }
        return CFTimeInterval(plane.vTime.values[index])/1000.0
    }
}

private extension ZTimelineLabelDataSource {
    private func doUpdateContent() {
        if let plane = plane {
            pointsCount = plane.vTime.count!
        }
    }
    
    private func makeIndices() -> [Int]? {
        guard let graphView = graphView else {
            return nil
        }
        if pointsCount < 1 {
            return nil
        }
        
        let visibleSteps = graphView.getWidth() / Float(StepWidth)
        let pointsPerView = position2d.w * Float(pointsCount)
        let ptPerStep = (visibleSteps > 0.1) ? pointsPerView/visibleSteps : 0.0
        pointsPerStep.tryValue(ptPerStep)
        
        if pointsPerStep.value < 1 {
            return nil
        }
        let step = pointsPerStep.value
        let indexStart = (max(Int(ceil(position2d.x * Float(pointsCount))), 0) / step) * step + step/2
        let indexEnd   = min(Int(floor(position2d.sum * Float(pointsCount))), pointsCount - 1)
        if indexStart >= indexEnd {
            return nil
        }
        return stride(from: indexStart, through: indexEnd, by: step).map{ Int($0) }
    }
}
