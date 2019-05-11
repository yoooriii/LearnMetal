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
    
    var position: Float = 0 {
        didSet { positionDidChange() }
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
            
        case .ended:
            break
        case .cancelled:
            break
        case .failed:
            break

        }
    }
    
    private func positionDidChange() {
        let constantX = bounds.width * CGFloat(position)
        constraintArrow.constant = constantX
        
        let dh = position - 0.5
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

        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
        
        delegate?.overlayInfo(self, didChange: position)
    }
    
    func setInfo(text:String) {
        infoLabel.text = text
    }
}
