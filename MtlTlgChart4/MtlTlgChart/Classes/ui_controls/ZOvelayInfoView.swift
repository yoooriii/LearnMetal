//
//  ZOvelayInfoView.swift
//  MtlTlgChart3
//
//  Created by Leonid Lokhmatov on 5/11/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit

@objc protocol ZOvelayInfoViewDelegate {
    func overlayInfo(_ overlay:ZOvelayInfoView, didChange position: Float)
}

class ZOvelayInfoView: UIView {
    @IBOutlet var verticalArrowView: UIView!
    @IBOutlet var bannerView: UIView!
    @IBOutlet var infoLabel: UILabel!
    @IBOutlet var constraintArrow: NSLayoutConstraint!
    @IBOutlet var constraintBannerLead: NSLayoutConstraint!
    @IBOutlet var constraintBannerTrail: NSLayoutConstraint!
    @IBOutlet var tapRecognizer: UITapGestureRecognizer!
    @IBOutlet var delegate: ZOvelayInfoViewDelegate?
    
    private let histeresisStep = Float(0.03)
    
    var prevPosition: Float = 0
    var position: Float = 0 {
        willSet { prevPosition = position }
    }
    
    var isBannerLeftward: Bool = false {
        didSet {
            constraintBannerLead.isActive = isBannerLeftward
            constraintBannerTrail.isActive = !isBannerLeftward
        }
    }
    
    override func awakeFromNib() {
        constraintArrow.constant = 0
        constraintBannerTrail.isActive = false
    }
    
    @IBAction func tapAction(_ recognizer: UITapGestureRecognizer) {
        let pt = recognizer.location(in: self)
        position = Float(pt.x/bounds.width)
        updatePosition(animated: true)
    }
    
    @IBAction func dragAction(_ recognizer: UIPanGestureRecognizer) {
        let pt = recognizer.location(in: self)
        
        switch recognizer.state {
        case .possible:
            break
        case .began:
            recognizer.setTranslation(pt, in: self)
        case .changed:
            position = Float(pt.x/bounds.width)
            updatePosition(animated: false)
            
        case .ended, .cancelled, .failed:
            break
        }
    }
    
    private var animeID = Int(-1)
    
    private func updatePosition(animated:Bool) {
        let constantX = bounds.width * CGFloat(position)
        let startVal = constraintArrow.constant
        
        func moveBanner(pos:Float) {
            let dh = pos - 0.5
            if isBannerLeftward {
                if dh > histeresisStep {
                    isBannerLeftward = false
                }
            } else {
                if dh < -histeresisStep {
                    isBannerLeftward = true
                }
            }
            
            let hideBanner = position < -0.05 || position > 1.05
            bannerView.isHidden = hideBanner
        }
        
        ZAnimator.shared.removeAnime(id: animeID)
        animeID = -1
        if animated {
            func stepFunc(animator:ZAnimator, progress:Float) {
                let constant = startVal + (constantX - startVal) * CGFloat(progress)
                constraintArrow.constant = constant
                self.layoutIfNeeded()
                
                let pos = prevPosition + (position - prevPosition) * progress
                moveBanner(pos: pos)
                if let delegate = delegate {
                    delegate.overlayInfo(self, didChange: pos)
                }
            }
            
            let id = ZAnimator.shared.animate(duration: 0.5, stepBlock: stepFunc) { [weak self] animator, success in
                if let self = self {
                    self.animeID = -1
                    stepFunc(animator:animator, progress:1.0)
                }
            }
            animeID = id
        } else {
            moveBanner(pos: position)
            constraintArrow.constant = constantX
            delegate?.overlayInfo(self, didChange: position)
        }
    }
    
    func setInfo(text:String) {
        infoLabel.text = text
    }
}
