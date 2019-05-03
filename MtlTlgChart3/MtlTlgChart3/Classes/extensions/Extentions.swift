//
//  Extentions.swift
//  TelegramChart
//
//  Created by Leonid Lokhmatov on 3/13/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import simd

extension VectorAmplitude {
    var color: UIColor? {
        get { return UIColor(string:self.colorString) }
    }
    
    var colorVector: float4 {
        let defaultColorVector = float4(0,0,0,1) // let it be black
        guard var hex = self.colorString else { return defaultColorVector }
        if hex.count != 7 { return defaultColorVector }
        if hex.first != "#" { return defaultColorVector }
        hex.removeFirst()
        guard let rgb = UInt32(hex, radix:16) else { return defaultColorVector }
        
        return float4(Float((rgb >> 16) & 0xFF) / 255.0,
                      Float((rgb >> 8) & 0xFF) / 255.0,
                      Float(rgb & 0xFF) / 255.0,
                      1.0)
    }
}
