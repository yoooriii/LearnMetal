//
//  RawModels.swift
//  TestJson
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//  Copyright © 2019 Horns & Hoovs. All rights reserved.
//

import Foundation

/// Raw Models used to hold json models
/// no UIKit classes available here since the models supposed to work on macOS as well

struct RawColumn: Decodable, Encodable {
    let id: String!
    let values: [Int64]!
    let minValue: Int64!
    let maxValue: Int64!
    
    init(from decoder: Decoder) throws {
        var elements = try decoder.unkeyedContainer()
        id = try elements.decode(String.self)
        var minVal = Int64.max
        var maxVal = Int64.min
        var numbers = [Int64]()
        while !elements.isAtEnd {
            let num = try elements.decode(Int64.self)
            numbers.append(num)

            if minVal > num { minVal = num }
            if maxVal < num { maxVal = num }
        }
        values = numbers
        minValue = minVal
        maxValue = maxVal
    }
    
    func encode(to encoder: Encoder) throws {
        var elements = encoder.unkeyedContainer()
        try elements.encode(id)
        for v in values {
            try elements.encode(v)
        }
    }
}

struct RawPlane: Decodable, Encodable {
    let columns: [RawColumn]!
    let colors: [String: String]!
    let names: [String: String]!
    let types: [String: String]!
}
