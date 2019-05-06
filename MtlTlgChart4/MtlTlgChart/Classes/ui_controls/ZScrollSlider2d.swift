//
//  ZNextStepSlider2d.swift
//  SliderExtended
//
//  Created by Leonid Lokhmatov on 5/5/19.
//  Copyright © 2018 Luxoft. All rights reserved
//

import UIKit
import simd

@objc protocol ZScrollSlider2dDelegate {
    func scrollSlider(_ slider:ZScrollSlider2d, positionDidChange position2d:float2)
}


class ZScrollSlider2d: UIView {
    @IBOutlet var delegate:ZScrollSlider2dDelegate?
    @IBOutlet var handleView:UIView!
    @IBOutlet var handleViewLeft:UIView!
    @IBOutlet var handleViewRight:UIView!
    @IBOutlet var scrollView:UIScrollView!

    @IBOutlet var constraintLeft:NSLayoutConstraint!
    @IBOutlet var constraintCenter:NSLayoutConstraint!
    @IBOutlet var constraintRight:NSLayoutConstraint!
    @IBOutlet var constraintLeftMin:NSLayoutConstraint!
    @IBOutlet var constraintRightMin:NSLayoutConstraint!
    
    private var dragLeft:UIPanGestureRecognizer!
    private var dragRight:UIPanGestureRecognizer!    
    private var isDraggingRight = false
    private var isDraggingLeft = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        internalInit()
    }
    
    @objc func actDragLeft(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            isDraggingLeft = true
            self.layer.removeAllAnimations()
            scrollView.bounces = false
            scrollView.isScrollEnabled = false
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)

            recognizer.setTranslation(CGPoint(x:constraintLeft.constant, y:0), in: self)
            constraintRight.constant = bounds.width - constraintLeft.constant - constraintCenter.constant
            constraintLeft.priority = .high
            constraintCenter.priority = .low
            constraintRight.priority = .middle

            constraintRightMin.isActive = true
            break
            
        case .changed:
            constraintLeft.constant = recognizer.translation(in: self).x
            positionDidChange()
            break
            
        case .possible:
            break
            
        case .ended, .cancelled, .failed:
            constraintLeft.constant = handleView.frame.minX
            constraintCenter.constant = handleView.frame.width
            dragEndRestoreConstraintPriority()
            constraintRightMin.isActive = false
            isDraggingLeft = false
            break
        }
    }
    
    @objc func actDragRight(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            isDraggingRight = true
            self.layer.removeAllAnimations()
            scrollView.bounces = false
            scrollView.isScrollEnabled = false
            scrollView.setContentOffset(scrollView.contentOffset, animated: false)

            let rightW = bounds.width - constraintLeft.constant - constraintCenter.constant
            constraintRight.constant = rightW
            recognizer.setTranslation(CGPoint(x:-constraintRight.constant, y:0), in: self)
            constraintLeft.priority = .middle
            constraintCenter.priority = .low
            constraintRight.priority = .high

            constraintLeftMin.isActive = true
            break
            
        case .changed:
            let x = recognizer.translation(in: self).x
            constraintRight.constant = -x
            positionDidChange()
            break
            
        case .possible:
            break
            
        case .ended, .cancelled, .failed:
            constraintLeft.constant = handleView.frame.minX
            constraintCenter.constant = handleView.frame.width
            dragEndRestoreConstraintPriority()
            constraintLeftMin.isActive = false
            isDraggingRight = false
            break
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateScrollContent()
        
        //TODO: DEBUG
//        handleView.layer.cornerRadius = 20
//        handleView.layer.borderWidth = 1
//        handleView.layer.borderColor = UIColor.red.cgColor
    }
    
    func position2d() -> float2 {
        let maxW = scrollView.frame.width
        let w0 = handleView.frame.minX - scrollView.frame.minX
        let w1 = handleView.frame.width
        return float2(Float(w0/maxW), Float(w1/maxW))
    }
    
    func setPosition2d(_ pos: float2) {
        let sum = pos[0] + pos[1]
        guard sum <= 1.0 else {
            print(String(format: "Slider2d: Wrong position, ignore. [%2.2f + %2.2f = %2.2f]", pos[0], pos[1], sum))
            return
        }
        let maxW = scrollView.frame.width
        constraintLeft.constant = maxW * CGFloat(pos[0])
        constraintCenter.constant = maxW * CGFloat(pos[1])
    }
}


private extension ZScrollSlider2d {
    func internalInit() {
        dragLeft = UIPanGestureRecognizer(target: self, action: #selector(actDragLeft(_:)))
        dragLeft.minimumNumberOfTouches = 1
        dragLeft.maximumNumberOfTouches = 1
        dragRight = UIPanGestureRecognizer(target: self, action: #selector(actDragRight(_:)))
        dragRight.minimumNumberOfTouches = 1
        dragRight.maximumNumberOfTouches = 1

        handleViewLeft.addGestureRecognizer(dragLeft)
        handleViewRight.addGestureRecognizer(dragRight)
    }
    
    func updateScrollContent() {
        var contentSize = scrollView.frame.size
        contentSize.width = 2.0 * contentSize.width - constraintCenter.constant
        scrollView.contentSize = contentSize
        
        let x = scrollView.frame.maxX - constraintLeft.constant - constraintCenter.constant
        scrollView.contentOffset = CGPoint(x:x, y:0)
    }
    
    func positionDidChange() {
        let pos2d = position2d()
        if let delegate = delegate {
            delegate.scrollSlider(self, positionDidChange: pos2d)
        }
    }

    private func dragEndRestoreConstraintPriority() {
        constraintLeft.priority = .high
        constraintCenter.priority = .high
        constraintRight.priority = .low
        
        scrollView.bounces = true
        scrollView.isScrollEnabled = true
        updateScrollContent()
        scrollView.layer.removeAllAnimations()
    }
}


extension ZScrollSlider2d: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetX = scrollView.frame.maxX - scrollView.contentOffset.x - constraintCenter.constant
        if !isDraggingRight && !isDraggingLeft {
            constraintLeft.constant = offsetX
        }
        positionDidChange()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        constraintRightMin.isActive = false
        constraintLeftMin.isActive = false
    }
}


extension UILayoutPriority {
    static let middle = UILayoutPriority(rawValue: 700)
    static let low = UILayoutPriority(rawValue: 200)
    static let high = UILayoutPriority(rawValue: 999)
}
