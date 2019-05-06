//
//  Extentions.swift
//  TelegramChart
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
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
