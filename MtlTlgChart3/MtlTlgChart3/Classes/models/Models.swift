//
//  Models.swift
//  TestJson
//
//  Created by Yu Lo on 3/12/19.
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
    let normal: Double!
    let scale: Double!

    var count:Int {
        return values.count
    }

    required init(_ rawColumn:RawColumn, normal:Double) {
        id = rawColumn.id
        values = rawColumn.values
        minValue = rawColumn.minValue!
        maxValue = rawColumn.maxValue!

        self.normal = normal
        scale = Double(maxValue - minValue) / normal
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

    func avg() -> Float {
        var val = Float(0)
        for v in values {
            val += Float(v)
        }
        return val/Float(count)
    }
}

// type 'x'
class VectorTime: BasicVector {
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
