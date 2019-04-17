//
//  UIColor+z42.swift
//  TelegramChart
//
//  Created by Leonid Lokhmatov on 3/13/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit

extension UIColor {
    // MARK: - PRIMARY COLORS
    static let internalBlue = UIColor(red: 0, green: 170, blue: 231)
    static let internalPink = UIColor(red: 214, green: 0, blue: 128)

    convenience init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.init(red: red/255, green: green/255, blue: blue/255, alpha: 1.0)
    }

    convenience init?(string: String?) {
        guard var hex = string else { return nil }
        if hex.count != 7 { return nil }
        if hex.first != "#" { return nil }
        hex.removeFirst()
        guard let rgb = UInt32(hex, radix:16) else { return nil }
        self.init(rgb:rgb)
    }

    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(rgb & 0xFF) / 255.0,
                  alpha: 1)
    }

    static func random() -> UIColor {
        let max = CGFloat(UInt32.max)
        let r = CGFloat(arc4random())/max
        let g = CGFloat(arc4random())/max
        let b = CGFloat(arc4random())/max
        return UIColor(red:r, green:g, blue:b, alpha:1.0)
    }
}
