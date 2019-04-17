//
//  Extentions.swift
//  TelegramChart
//
//  Created by Leonid Lokhmatov on 3/13/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit

extension VectorAmplitude {
    var color: UIColor? {
        get { return UIColor(string:self.colorString) }
    }
}
