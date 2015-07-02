//
//  oalSpatialView.swift
//  oalTouch
//
//  CTranslated by OOPer in cooperation with shlab.jp, on 2015/7/3.
//
//
/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
A visual representation of our sound stage.
*/

import UIKit

let kTouchDistanceThreshhold: CGFloat = 45.0

// A function to bring an outlying point into the bounds of a rectangle,
// so that it is as close as possible to its original outlying position.
private func CGPointWithinBounds(point: CGPoint, bounds: CGRect) -> CGPoint {
    var ret = point
    if ret.x < CGRectGetMinX(bounds) { ret.x = CGRectGetMinX(bounds) }
    else if ret.x > CGRectGetMaxX(bounds) { ret.x = CGRectGetMaxX(bounds) }
    if ret.y < CGRectGetMinY(bounds) { ret.y = CGRectGetMinY(bounds) }
    else if ret.y > CGRectGetMaxY(bounds) { ret.y = CGRectGetMaxY(bounds) }
    return ret
}

private func CreateRoundedRectPath(RECT: CGRect, var cornerRadius: CGFloat) -> CGPath {
    let path = CGPathCreateMutable()

    let maxRad = max(CGRectGetHeight(RECT) / 2.0, CGRectGetWidth(RECT) / 2.0)

    if cornerRadius > maxRad { cornerRadius = maxRad }

    var bl: CGPoint, tl: CGPoint, tr: CGPoint, br: CGPoint

    bl = RECT.origin
    tl = RECT.origin
    tr = RECT.origin
    br = RECT.origin
    tl.y += RECT.size.height
    tr.y += RECT.size.height
    tr.x += RECT.size.width
    br.x += RECT.size.width

    CGPathMoveToPoint(path, nil, bl.x + cornerRadius, bl.y)
    CGPathAddArcToPoint(path, nil, bl.x, bl.y, bl.x, bl.y + cornerRadius, cornerRadius)
    CGPathAddLineToPoint(path, nil, tl.x, tl.y - cornerRadius)
    CGPathAddArcToPoint(path, nil, tl.x, tl.y, tl.x + cornerRadius, tl.y, cornerRadius)
    CGPathAddLineToPoint(path, nil, tr.x - cornerRadius, tr.y)
    CGPathAddArcToPoint(path, nil, tr.x, tr.y, tr.x, tr.y - cornerRadius, cornerRadius)
    CGPathAddLineToPoint(path, nil, br.x, br.y + cornerRadius)
    CGPathAddArcToPoint(path, nil, br.x, br.y, br.x - cornerRadius, br.y, cornerRadius)

    CGPathCloseSubpath(path)

    let ret = CGPathCreateCopy(path)
    return ret
}

@objc(oalSpatialView)
class oalSpatialView: UIView {
    // Reference to our playback object, wired up in IB
    @IBOutlet var playback: oalPlayback!
    
    // Images for the speaker in its on and off state
    var _speaker_off: CGImage!
    var _speaker_on: CGImage!
    
    // Various layers we use to represent things in the sound stage
    var _draggingLayer: CALayer!
    var _speakerLayer: CALayer!
    var _listenerLayer: CALayer!
    var _instructionsLayer: CALayer!

//MARK: Object Init / Maintenance

    required init(coder: NSCoder) {
        super.init(coder: coder)
        self.initializeContents()
    }

    deinit {
        playback.removeObserver(self, forKeyPath: "sourcePos")
        playback.removeObserver(self, forKeyPath: "isPlaying")
        playback.removeObserver(self, forKeyPath: "listenerPos")
        playback.removeObserver(self, forKeyPath: "listenerRotation")

    }

    override func awakeFromNib() {
	// We want to register as an observer for the oalPlayback environment, so we'll get notified when things
	// change, i.e. source position, listener position.
        playback.addObserver(self, forKeyPath: "sourcePos", options: .New, context: nil)
        playback.addObserver(self, forKeyPath: "isPlaying", options: .New, context: nil)
        playback.addObserver(self, forKeyPath: "listenerPos", options: .New, context: nil)
        playback.addObserver(self, forKeyPath: "listenerRotation", options: .New, context: nil)

        playback.checkForMusic()
        self.layoutContents()
    }


//MARK: KVO

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
	// Generally, we just call [self layoutContents] whenever something changes in the oalPlayback environment.
	// When the sound sound source is turned on or off, we also change the image for the speaker to either show
	// or hide the sound waves.

        if object === playback && keyPath == "sourcePos" {
            self.layoutContents()
        } else if object === playback && keyPath == "isPlaying" {
            self.layoutContents()
            if playback.isPlaying {
                _speakerLayer.contents = _speaker_on
            } else {
                _speakerLayer.contents = _speaker_off
            }
        } else if object === playback && keyPath == "listenerPos" {
            self.layoutContents()
        } else if object === playback && keyPath == "listenerRotation" {
            self.layoutContents()
        } else {
            fatalError("\(self) observing unexpected keypath \(keyPath) for object \(object)")
        }
    }



//MARK: View contents

    func initializeContents() {
	// Load images for the two speaker states and retain them, because we'll be switching between them
        _speaker_off = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("speaker_off", ofType: "png")!)!.CGImage

        _speaker_on = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("speaker_on", ofType: "png")!)!.CGImage

        let listenerImg = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("listener", ofType: "png")!)!.CGImage
        let instructionsImg = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("instructions", ofType: "png")!)!.CGImage

	// Set up the CALayer which shows the speaker
        _speakerLayer = CALayer()
        _speakerLayer.frame = CGRectMake(0.0, 0.0, CGImageGetWidth(_speaker_off).g, CGImageGetHeight(_speaker_off).g)
        _speakerLayer.contents = _speaker_off

	// Set up the CALayer which shows the listener
        _listenerLayer = CALayer()
        _listenerLayer.frame = CGRectMake(0.0, 0.0, CGImageGetWidth(listenerImg).g, CGImageGetHeight(listenerImg).g)
        _listenerLayer.contents = listenerImg
        _listenerLayer.anchorPoint = CGPointMake(0.5, 0.57)

	// Set up the CALayer which shows the instructions
        _instructionsLayer = CALayer()
        _instructionsLayer.frame = CGRectMake(0.0, 0.0, CGImageGetWidth(instructionsImg).g, CGImageGetHeight(instructionsImg).g)
        _instructionsLayer.position = CGPointMake(0.0, -140.0)
        _instructionsLayer.contents = instructionsImg

	// Set a sublayerTransform on our view's layer. This causes (0,0) to be in the center of the view. This transform
	// is useful because now our view's coordinates map precisely to our oalPlayback sound environment's coordinates.
        let trans = CATransform3DMakeTranslation(self.frame.size.width / 2.0, self.frame.size.height / 2.0, 0.0)
        self.layer.sublayerTransform = trans

	// Set the background image for the sound stage
        let bgImg = UIImage(contentsOfFile: NSBundle.mainBundle().pathForResource("stagebg", ofType: "png")!)!.CGImage
        self.layer.contents = bgImg

	// Add our sublayers
        self.layer.insertSublayer(_speakerLayer, above: self.layer)
        self.layer.insertSublayer(_listenerLayer, above: self.layer)
        self.layer.insertSublayer(_instructionsLayer, above: self.layer)

	// Prevent things from drawing outside our layer bounds
        self.layer.masksToBounds = true
    }

    func layoutContents() {
	// layoutContents gets called via KVO whenever properties within our oalPlayback object change

	// Wrap these layer changes in a transaction and set the animation duration to 0 so we don't get implicit animation
        CATransaction.begin()
        CATransaction.setValue(0.0, forKey: kCATransactionAnimationDuration)

	// Position and rotate the listener
        _listenerLayer.position = playback.listenerPos
        _listenerLayer.transform = CATransform3DMakeRotation(playback.listenerRotation, 0.0, 0.0, 1.0)

	// The speaker gets rotated so that it's always facing the listener
        let rot = atan2(-(playback.sourcePos.x - playback.listenerPos.x), playback.sourcePos.y - playback.listenerPos.y)

	// Rotate and position the speaker
        _speakerLayer.position = playback.sourcePos
        _speakerLayer.transform = CATransform3DMakeRotation(rot, 0.0, 0.0, 1.0)

        CATransaction.commit()
    }


//MARK: Events

    private func touchPoint(pt: CGPoint) {
        if !_instructionsLayer.hidden { _instructionsLayer.hidden = true }

        if _draggingLayer === _speakerLayer { playback.sourcePos = pt }
        else if _draggingLayer === _listenerLayer { playback.listenerPos = pt }
    }

    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        var pointInView = (touches.first! as! UITouch).locationInView(self)

	// Clip our pointInView to within 5 pixels of any edge, so we can't position objects near or beyond
	// the edge of the sound stage
        pointInView = CGPointWithinBounds(pointInView, CGRectInset(self.bounds, 5.0, 5.0))

	// Convert the view point to our layer / sound stage coordinate system, which is centered at (0,0)
        let pointInLayer = CGPointMake(pointInView.x - self.frame.size.width / 2.0, pointInView.y - self.frame.size.height / 2.0)

	// Find out if the distance between the touch is within the tolerance threshhold for moving
	// the source object or the listener object
        if hypot(playback.sourcePos.x - pointInLayer.x, playback.sourcePos.y - pointInLayer.y) < kTouchDistanceThreshhold {
            _draggingLayer = _speakerLayer
        } else if hypot(playback.listenerPos.x - pointInLayer.x, playback.listenerPos.y - pointInLayer.y) < kTouchDistanceThreshhold {
            _draggingLayer = _listenerLayer
        } else {
            _draggingLayer = nil
        }

	// Handle the touch
        self.touchPoint(pointInLayer)
    }

    override func touchesMoved(touches: Set<NSObject>, withEvent event: UIEvent) {
	// Called repeatedly as the touch moves

        var pointInView = (touches.first! as! UITouch).locationInView(self)
        pointInView = CGPointWithinBounds(pointInView, CGRectInset(self.bounds, 5.0, 5.0))
        let pointInLayer = CGPointMake(pointInView.x - self.frame.size.width / 2.0, pointInView.y - self.frame.size.height / 2.0)
        self.touchPoint(pointInLayer)
    }

    override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent) {
        _draggingLayer = nil
    }



}