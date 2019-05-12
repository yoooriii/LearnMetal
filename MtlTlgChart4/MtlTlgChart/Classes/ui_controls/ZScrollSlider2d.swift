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
    
    private var doubleTaps = [UITapGestureRecognizer]()
    private var dragLeft:UIPanGestureRecognizer!
    private var dragRight:UIPanGestureRecognizer!    
    private var isDraggingRight = false
    private var isDraggingLeft = false
    private var scrollAnimationInFlight = false
    private let sideMargin = CGFloat(10)  // left & right margins (the handle should not go there)

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
    
    
    @objc func actDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let pt1 = recognizer.location(in: handleView)
        
        var constX = constraintLeft.constant

        if handleView.bounds.contains(pt1) {
// implement it
        } else {
            let pt0 = recognizer.location(in: self)
            constX = pt0.x - handleView.frame.width/2.0
            if pt1.x < handleView.bounds.minX {
                // left side tap
                if constX < sideMargin {
                    constX = sideMargin
                }
            } else if pt1.x > handleView.bounds.maxX {
                // right side tap
                if constX > bounds.width - handleView.frame.width - sideMargin {
                    constX = bounds.width - handleView.frame.width - sideMargin
                }
            } else {
                /*we should not get here*/
                return
            }
        }
        
        if abs(constX - constraintLeft.constant) > 5 { // just in case compare
            scrollAnimationInFlight = true
            driveScrollAnime(to: constX)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !scrollAnimationInFlight {
            updateScrollContent(animated: false)
        }
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
        // config recognizers
        dragLeft = UIPanGestureRecognizer(target: self, action: #selector(actDragLeft(_:)))
        dragLeft.minimumNumberOfTouches = 1
        dragLeft.maximumNumberOfTouches = 1
        dragRight = UIPanGestureRecognizer(target: self, action: #selector(actDragRight(_:)))
        dragRight.minimumNumberOfTouches = 1
        dragRight.maximumNumberOfTouches = 1
        
        handleViewLeft.addGestureRecognizer(dragLeft)
        handleViewRight.addGestureRecognizer(dragRight)
        handleViewLeft.isExclusiveTouch = false
        handleViewRight.isExclusiveTouch = false

        // add 3 double tap recognizers
        let doubleTapViews:[UIView] = [scrollView, handleViewLeft, handleViewRight]
        doubleTaps.removeAll() // just in case
        for view in doubleTapViews {
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(actDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTap)
            doubleTaps.append(doubleTap)
        }

        // config appearance
        handleView.layer.borderWidth = 2.0
        handleView.layer.borderColor = UIColor.gray.cgColor
    }
    
    func updateScrollContent(animated:Bool) {
        scrollContent(to:constraintLeft.constant, animated: animated)
        
//        var contentSize = scrollView.frame.size
//        contentSize.width = 2.0 * contentSize.width - constraintCenter.constant
//        scrollView.contentSize = contentSize
//
//        let x = scrollView.frame.maxX - constraintLeft.constant - constraintCenter.constant
//        scrollView.contentOffset = CGPoint(x:x, y:0)
    }

    func scrollContent(to leftX:CGFloat, animated:Bool) {
        var contentSize = scrollView.frame.size
        contentSize.width = 2.0 * contentSize.width - constraintCenter.constant
        scrollView.contentSize = contentSize
        
        let x = scrollView.frame.maxX - leftX - constraintCenter.constant
        if animated {  // non animation works differently!
            scrollView.setContentOffset(CGPoint(x:x, y:0), animated: true)
        } else {
            scrollView.contentOffset = CGPoint(x:x, y:0)
        }
    }
    
    func driveScrollAnime(to leftX:CGFloat) {
        let x = scrollView.frame.maxX - leftX - constraintCenter.constant
        scrollView.setContentOffset(CGPoint(x:x, y:0), animated: true)
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
        updateScrollContent(animated: false)
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
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollAnimationInFlight = false
    }
}


extension UILayoutPriority {
    static let middle = UILayoutPriority(rawValue: 700)
    static let low = UILayoutPriority(rawValue: 200)
    static let high = UILayoutPriority(rawValue: 999)
}
