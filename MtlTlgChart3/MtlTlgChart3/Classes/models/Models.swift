//
//  Models.swift
//  TestJson
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//  Copyright © 2019 Horns & Hoovs. All rights reserved.
//

import Foundation
import CoreGraphics

/// models convenient for ios/macOS internal logic (when raw json models aren't)
/// no UIKit classes available here since the models supposed to work on macOS as well

/// basic interface for both types (x and line)
protocol Vector {
    var id: String! {get set}
    var values: [Int64]! {get set}
    var minValue: Int64 {get set}
    var maxValue: Int64 {get set}
}

struct MinMax {
    let min:CGFloat!
    let max:CGFloat!
}

struct MinMaxI64 {
    let min: Int64!
    let max: Int64!
}

struct Range {
    let origin: Double!
    let length: Double!
    var end:Double { get { return origin + length } }
    init(origin:CGFloat, length:CGFloat) {
        self.origin = Double(origin)
        self.length = Double(length)
    }
}

class BasicVector: Vector {
    var id: String!
    var values: [Int64]!
    var minValue: Int64
    var maxValue: Int64
    let avgValue: Double!
    let normal: Double!
    let scale: Double!

    var count: Int! {
        return values.count
    }

    required init(id:String, values: [Int64]!) {
        self.id = id
        self.values = values

        var _min = Int64.max
        var _max = Int64.min
        var _median = Double(0)
        for v in values {
            _median += Double(v)
            if _min > v { _min = v }
            if _max < v { _max = v }
        }
        minValue = _min
        maxValue = _max
        avgValue = _median/Double(values.count)

        normal = 0
        scale = 0
    }

    required init(_ rawColumn:RawColumn, normal:Double) {
        id = rawColumn.id
        values = rawColumn.values
        minValue = rawColumn.minValue!
        maxValue = rawColumn.maxValue!

        self.normal = normal
        scale = Double(maxValue - minValue) / normal

        var val = Double(0)
        for v in values {
            val += Double(v)
        }
        avgValue = val/Double(values.count)
    }
    
    func copy(in range:NSRange) -> BasicVector? {
        let count = values.count
        if (range.location >= count) {
            print("BasicVector copy(range): location out of range \(range.location) >= \(count))")
            return nil
        }
        let endItem = range.location + range.length
        if (endItem >= count) {
            print("BasicVector copy(range): end location out of range \(endItem) >= \(count)")
            return nil
        }
        let rangeValues = Array<Int64>(values[range.location ..< endItem])
        let copy = type(of: self).init(id: self.id, values: rangeValues)
        return copy
    }
    

//    func toNormal(_ originalValue:Int64) -> Double {
//        return Double(originalValue - minValue)/scale
//    }

    func normalValue(at index:Int) -> Double {
        let originalValue = values[index]
        return Double(originalValue - minValue)/scale
    }

    func normalValue1(at index:Int) -> Double {
        let originalValue = values[index]
        return (Double(originalValue - minValue)/scale)/normal
    }

    func fromNormal(_ normalizedValue:Double) -> Int64 {
        return Int64(normalizedValue * scale) + minValue
    }

}

// type 'x'
class VectorTime: BasicVector {
    override func copy(in range:NSRange) -> VectorTime? {
        if let copy = super.copy(in: range) as? VectorTime {
            return copy
        }
        return nil
    }
}

// type 'line'
class VectorAmplitude: BasicVector {
    var name: String!
    var colorString: String!

    convenience init(_ rawColumn:RawColumn, colorString: String!, name: String!, normal:Double) {
        self.init(rawColumn, normal:normal)
        self.colorString = colorString
        self.name = name
    }
    
    override func copy(in range: NSRange) -> VectorAmplitude? {
        if let copy = super.copy(in: range) as? VectorAmplitude {
            copy.name = name
            copy.colorString = colorString
            return copy
        }
        return nil
    }
}

/// class to represent a plane with one x and many y points (axes)
class Plane {
    enum VectorType: String {
        case x = "x"
        case line = "line"
    }

    var vTime: VectorTime!
    var vAmplitudes: [VectorAmplitude]!
    // key: VectorAmplitude.name; value: @localizedName
    var localizedNames: [String:String]?
    
    init(vTime:VectorTime, vAmplitudes:[VectorAmplitude]) {
        self.vTime = vTime
        self.vAmplitudes = vAmplitudes
    }

    init(rawPlane:RawPlane, normal:Double) {
        var amplitudes = [VectorAmplitude]()
        for aColumn in rawPlane.columns {
            // simple validation logic to prevent using invalid vectors
            guard let id = aColumn.id else { continue }
            guard let rawType = rawPlane.types[id] else { continue }
            guard let type = VectorType(rawValue: rawType) else { continue }

            switch type {
            case .x:
                // FIXIT: what if there is more than one x type item?
                vTime = VectorTime(aColumn, normal:normal)

            case .line:
                let color = rawPlane.colors[id]
                let name = rawPlane.names[id]
                let amp = VectorAmplitude(aColumn, colorString:color, name:name, normal:normal)
                amplitudes.append(amp)
            }
        }
        vAmplitudes = amplitudes
    }
    
    func info() -> String {
        var string = "Plane: "
        string += "charts:[\(vAmplitudes.count)]"
        if vAmplitudes.count > 0 {
            string += " {"
            for amp in vAmplitudes {
                string += " \(amp.count!)"
            }
            string += " }"
        }
        string += " x time[\(vTime.count!)]"
        return string
    }
    
    func copy(in range:NSRange) -> Plane? {
        if range.location >= vTime.count {
            print("cannot copy: location out of range [\(range.location) >= \(vTime.count!)]")
            return nil
        }
        let endIndex = range.location + range.length
        if endIndex >= vTime.count {
            print("cannot copy: end location out of range [\(endIndex) >= \(vTime.count!)]")
            return nil
        }
        
        if let copyVTime = vTime.copy(in: range) {
            var copyVAmplitudes = [VectorAmplitude]()
            for amp in vAmplitudes {
                if let nextAmp = amp.copy(in: range) {
                    copyVAmplitudes.append(nextAmp)
                }
            }
            return Plane(vTime: copyVTime, vAmplitudes: copyVAmplitudes)
        }
        
        return nil
    }
}

struct GraphicsContainer: Decodable {
    let planes: [Plane]!
    var size:Int { get { return planes.count } }

    init(from decoder: Decoder) throws {
        var rawItems = try decoder.unkeyedContainer()
        var planes = [Plane]()
        while !rawItems.isAtEnd {
            let rawPlane = try rawItems.decode(RawPlane.self)
            let plane = Plane(rawPlane:rawPlane, normal:Double(LogicCanvas.SIZE))
            planes.append(plane)
        }
        self.planes = planes
    }

    func setLocalizedNames(localizedNames: [String:String]?) {
        for plane in planes {
            plane.localizedNames = localizedNames
        }
    }
}
