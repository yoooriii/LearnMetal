//
//  NSError+z42.swift
//  TelegramChart
//
//  Created by Yu Lo on 3/19/19.
//  Copyright © 2019 Horns & Hoovs. All rights reserved.
//

import Foundation

extension NSError {
    convenience init(_ message:String) {
        let userInfo = [NSLocalizedDescriptionKey:message]
        self.init(domain:"Telegram Chart App", code:-1, userInfo:userInfo)
    }
}
