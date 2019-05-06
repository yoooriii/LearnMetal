//
//  LogicCanvas.swift
//  TelegramChart
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//  Copyright © 2019 Horns & Hoovs. All rights reserved.
//

//import Foundation
//import CoreGraphics
import UIKit

/// in essence this is a data provider class
/// this class represents a square of the logic size @SIZE 1000x1000
/// the locic coordinates should be translated to the @viewSize coordinates to show in the view
class LogicCanvas {
    static var SIZE = CGFloat(1000)
    var lineWidth = CGFloat(2)
    var viewSize = CGSize(width:100, height:100) {
        didSet {
            // update the scale value once the view size change
            scale = CGPoint(x:LogicCanvas.SIZE / viewSize.width, y:LogicCanvas.SIZE / viewSize.height)
            // changing the view size makes all cached slices invalid
            cachedSlices.removeAllObjects()
        }
    }
    var tileRect = CGRect(x:0, y:0, width:100, height:100)
    private var scale = CGPoint(x:1.0, y:1.0)

    func pointsFrom(normalY: CGFloat) -> CGFloat {
        return normalY / scale.y
    }

    private var vTime: VectorTime!
    var count:Int { get { return vTime.values.count } }

    private var vAmplitudes: [VectorAmplitude]!
    //TODO: think: if one of amplitudes goes hidden, should we amp's min/max/scale update?
    private var minAmplitude: Int64!
    private var maxAmplitude: Int64!
    private var scaleAmplitude: CGFloat!

    // returns logic min & max amplitudes
    func getMinMax() -> MinMax {
        return MinMax(min:normalizeAmplitude(minAmplitude), max:normalizeAmplitude(maxAmplitude))
    }

    //TODO: decide what to keep Plane or Plane's properties
    init(plane:Plane) {
        vTime = plane.vTime
        vAmplitudes = plane.vAmplitudes
        scaleAmplitude = updateAmplitudes()
    }

    func getVectorTime() -> VectorTime {
        return vTime
    }

    private var cachedSlices = NSCache<NSString, Slice>()

    // get cached slice or create a new one and cache it
    func getSlice(at index:Int) -> Slice? {
        let key = String(index) as NSString
        if let slc = cachedSlices.object(forKey:key) {
            return slc
        }
        if let slc = slice(at:index) {
            cachedSlices.setObject(slc, forKey:key)
            return slc
        }
        return nil
    }

    // based on the @tileRect
    private func slice(at index:Int) -> Slice? {
        // copy & move tile rect along the x axe
        var rect = self.tileRect
        rect.origin.x = rect.width * CGFloat(index)
        return slice(rect:rect)
    }

    // rect in view (screen) coordinates
    // result is in view (screen) coordinates
    func slice(rect:CGRect) -> Slice? {
        let rangeX = MinMax(min: rect.minX * scale.x, max:rect.maxX * scale.x)
        guard let indiceRange = self.indiceRange(rangeX:rangeX) else { return nil }
        let indices = indiceRange.start...indiceRange.end
//        print("SLICE: [\(indices)] from: \(count)")

        // start & end indices found, continue
        let viewMinY = rect.minY * scale.y
        var pathModels = [PathModel]()
        for vAmp in vAmplitudes {
            var minAmp = Int64.max
            var maxAmp = Int64.min
            let path = CGMutablePath()
            var isFirst = true
            for idx in indices {
                let arValue = vAmp.values[idx]
                if minAmp > arValue { minAmp = arValue }
                if maxAmp < arValue { maxAmp = arValue }

                let ptX = (CGFloat(vTime.normalValue(at:idx)) - rangeX.min) / scale.x
                let ampVal = self.normalizeAmplitude(arValue)
                let ptY = (ampVal - viewMinY) / scale.y
                let pt = CGPoint(x:ptX, y:ptY)

                if isFirst {  // rationale: the 1st point move() and the rest addLine()
                    isFirst = false
                    path.move(to: pt)
                    continue
                }

                path.addLine(to: pt)
            }
            let color = vAmp.color ?? UIColor.black
            let pm = PathModel(path:path, color:color, lineWidth:lineWidth, min:minAmp, max:maxAmp)
            pathModels.append(pm)
        }
        return Slice(pathModels:pathModels, rect:rect, indices:indiceRange)
    }

    func getExtremum(_ indices:[Int]) -> MinMax? {
        var min = Int64.max
        var max = Int64.min
        for idx in indices {
            if let pathModels = getSlice(at: idx)?.pathModels {
                for pm in pathModels {
                    if min > pm.min { min = pm.min }
                    if max < pm.max { max = pm.max }
                }
            }
        }
        guard min < max else { return nil }
        return MinMax(min:normalizeAmplitude(min), max:normalizeAmplitude(max))
    }

    // range in screen (view) coordinates
    // the result extremun in logic points
    func getExtremum(in range:Range) -> MinMax? {
        if count < 1 {
            return nil
        }
        // translate screen coord's --> logic coord's -> indices
        let rangeX = MinMax(min:CGFloat(range.origin) * scale.x, max:CGFloat(range.end) * scale.x)
        guard let indiceRange = self.indiceRange(rangeX:rangeX) else { return nil }
        let indices = indiceRange.start...indiceRange.end
//        print("SLICE: [\(indices)] from: \(count)")

        var minValue = Int64.max
        var maxValue = Int64.min

        for amp in vAmplitudes {
            for i in indices {
                let val = amp.values[i]
                if minValue > val {
                    minValue = val
                }
                if maxValue < val {
                    maxValue = val
                }
            }
        }
        if minValue > maxValue {
            return nil
        }

        // translate real values into logic points
        return MinMax(min:normalizeAmplitude(minValue), max:normalizeAmplitude(maxValue))
    }

    // input range in logic points
    // the result extremun in logic points
    func getLogicExtremum(in range:Range) -> MinMax? {
        if count < 1 {
            return nil
        }
        // translate screen coord's --> logic coord's -> indices
        let rangeX = MinMax(min:CGFloat(range.origin), max:CGFloat(range.end))
        guard let indiceRange = self.indiceRange(rangeX:rangeX) else { return nil }
        let indices = indiceRange.start...indiceRange.end
//        print("SLICE: [\(indices)] from: \(count)")

        var minValue = Int64.max
        var maxValue = Int64.min

        for amp in vAmplitudes {
            for i in indices {
                let val = amp.values[i]
                if minValue > val {
                    minValue = val
                }
                if maxValue < val {
                    maxValue = val
                }
            }
        }
        if minValue > maxValue {
            return nil
        }

        // translate real values into logic points
        return MinMax(min:normalizeAmplitude(minValue), max:normalizeAmplitude(maxValue))
    }

    func createPlane3d() -> Plane3d {
        // convert plane to Plane3d
        let bounds = CGRect(x:0, y:0, width:LogicCanvas.SIZE, height:LogicCanvas.SIZE)
        var arrP2d = [Plane2d]()
        for amp in vAmplitudes {
            var p2d = Plane2d(vTime:vTime, vAmplitude:amp)
            p2d.color = amp.color
            p2d.bounds = bounds
            p2d.path = p2d.pathInRect(bounds)
            arrP2d.append(p2d)
        }
        return Plane3d(planes:arrP2d)
    }

    private func updateAmplitudes() -> CGFloat {
        var min = Int64.max
        var max = Int64.min
        for amp in vAmplitudes {
            for v in amp.values {
                if min > v { min = v }
                if max < v { max = v }
            }
        }
        minAmplitude = min
        maxAmplitude = max
        return CGFloat(max - min) / CGFloat(LogicCanvas.SIZE)
    }

    private func indiceRange(rangeX:MinMax) -> Indices? {
        if rangeX.min > LogicCanvas.SIZE {
            // out of range
            return nil
        }
        guard let timeVals = vTime.values else {
            return nil
        }
        //TODO: replace linear look up algorithm with 2 step approach or smth
        let startTime = vTime.fromNormal(Double(rangeX.min))
        var iStart = 0
        for i in 0..<timeVals.count {
            let time = timeVals[i]
            if time >= startTime {
                iStart = i
                break
            }
        }
        let endTime = vTime.fromNormal(Double(rangeX.max))
        var iEnd = iStart
        for i in iStart..<timeVals.count {
            let time = timeVals[i]
            if time >= endTime {
                iEnd = i
                break
            }
        }
        if iStart >= iEnd {
            iEnd = timeVals.count - 1
            if iStart >= iEnd {
                // nothing found
                print("SLICE: nothing found")
                return nil
            }
        }
        if iStart > 0 {
            // add one more point (start point) to the left
            iStart -= 1
        }

        return Indices(start:iStart, end:iEnd)
    }

    // it translates real values into logic (normalized) points
    private func normalizeAmplitude(_ originalValue:Int64) -> CGFloat {
        if 0.0 == scaleAmplitude { return 0.0 }
        return CGFloat(originalValue - minAmplitude)/scaleAmplitude
    }

    func debugDescription() -> String {
        return "LogicCanvas[\(count)]: { amp.min:max [\(self.minAmplitude!)):\(self.maxAmplitude!)]; tile.size: [\(Int(tileRect.width)) x \(Int(tileRect.height))] }"
    }
}
