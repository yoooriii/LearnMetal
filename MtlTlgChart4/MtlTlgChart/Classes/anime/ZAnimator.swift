//
//  ZAnimator.swift
//  MtlTlgChart4
//
//  Created by leonid@leeloo on 5/22/19 ©2019 Horns&Hoofs.®
//

import UIKit

typealias ZAnimeStepBlock = (_ animator:ZAnimator, _ progress:Float)->Void
typealias ZAnimeCompletedBlock = (_ animator:ZAnimator, _ completed:Bool)->Void

struct ZAnimeTarget {
    let id:Int
    var startTime:TimeInterval
    var endTime:TimeInterval
    var stepBlock: ZAnimeStepBlock?
    var completedBlock: ZAnimeCompletedBlock?
}

class ZAnimator: NSObject {
    static var shared = ZAnimator()
    
    private var counter = 0
    private var displayLink: CADisplayLink?
    private var animeInFlight = [Int: ZAnimeTarget]()
    
    
    func animate(duration:TimeInterval, stepBlock:ZAnimeStepBlock?, completedBlock:ZAnimeCompletedBlock?) -> Int {
        counter += 1
        createDisplayLinkIfNeeded()
        let now = CACurrentMediaTime()
        let animeObj = ZAnimeTarget(id:counter, startTime:now, endTime: now+duration, stepBlock: stepBlock, completedBlock:completedBlock)
        animeInFlight[counter] = animeObj
        return counter
    }
    
    func removeAllAnimations() {
        if let _ = displayLink {
            displayLink?.invalidate()
            displayLink = nil
        }
        for (_, target) in animeInFlight {
            target.completedBlock?(self, false)
        }
        animeInFlight.removeAll()
    }
    
    func removeAnime(id: Int) {
        if let target = animeInFlight[id] {
            target.completedBlock?(self, true)
            animeInFlight[id] = nil
        }
    }
    
    func createDisplayLinkIfNeeded() {
        if let _ = displayLink { return }
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to: .current, forMode: .default)
    }
    
    @objc func step(displaylink: CADisplayLink) {
        let now = CACurrentMediaTime()
        var completed = [Int]()
        for (id, target) in animeInFlight {
            if now > target.endTime {
                target.completedBlock?(self, true)
                completed.append(id)
            } else {
                let dt = (now - target.startTime)/(target.endTime - target.startTime)
                target.stepBlock?(self, Float(dt))
            }
        }
        for id in completed {
            animeInFlight[id] = nil
        }
        if 0 == animeInFlight.count {
            displaylink.invalidate()
            self.displayLink = nil
        }
    }

}
