//
//  NSError+z42.swift
//  TelegramChart
//
//  Created by leonid@leeloo ©2019 Horns&Hoofs.®
//

import Foundation

extension NSError {
    convenience init(_ message:String) {
        let userInfo = [NSLocalizedDescriptionKey:message]
        self.init(domain:"Telegram Chart App", code:-1, userInfo:userInfo)
    }
}
