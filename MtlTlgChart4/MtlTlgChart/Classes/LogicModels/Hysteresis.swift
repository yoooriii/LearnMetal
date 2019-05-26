//
//  Hysteresis.swift
//  MtlTlgChart4
//
//  Updated by leonid@leeloo on 5/26/19 ©2019 Horns&Hoofs.®
//

import Foundation

typealias ValueChangeBlock = (_ from:Int, _ to:Int)->Void

class Hysteresis {
    private(set) var value:Int
    private let hz:Float
    public var valueChangeBlock:ValueChangeBlock?
    
    init(initialValue:Int = 0, hysteresis:Float = 0.1) {
        value = initialValue
        hz = hysteresis
    }
    
    @discardableResult
    func tryValue(_ val:Float) -> Bool {
        if val > Float(value) + 0.5 + hz {
            return doChangeValue(Int(ceil(val)))
        }
        
        if val < Float(value) - 0.5 - hz {
            return doChangeValue(Int(floor(val)))
        }
        
        return false
    }
    
    func resetValue(_ val:Int) {
        value = val
    }
    
    private func doChangeValue(_ val:Int) -> Bool {
        let doUpdate = value != val
        if doUpdate {
            let oldValue = value
            value = val
            valueChangeBlock?(oldValue, value)
        }
        return doUpdate
    }
}
