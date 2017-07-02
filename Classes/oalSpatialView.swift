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
private func CGPointWithinBounds(_ point: CGPoint, _ bounds: CGRect) -> CGPoint {
    var ret = point
    if ret.x < bounds.minX { ret.x = bounds.minX }
    else if ret.x > bounds.maxX { ret.x = bounds.maxX }
    if ret.y < bounds.minY { ret.y = bounds.minY }
    else if ret.y > bounds.maxY { ret.y = bounds.maxY }
    return ret
}

private func CreateRoundedRectPath(_ RECT: CGRect, _ _cornerRadius: CGFloat) -> CGPath {
    let path = CGMutablePath()

    let maxRad = max(RECT.height / 2.0, RECT.width / 2.0)

    var cornerRadius = _cornerRadius
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

    path.move(to: CGPoint(x: bl.x + cornerRadius, y: bl.y))
    path.addArc(tangent1End: CGPoint(x: bl.x, y: bl.y), tangent2End: CGPoint(x: bl.x, y: bl.y + cornerRadius), radius: cornerRadius)
    path.addLine(to: CGPoint(x: tl.x, y: tl.y - cornerRadius))
    path.addArc(tangent1End: CGPoint(x: tl.x, y: tl.y), tangent2End: CGPoint(x: tl.x + cornerRadius, y: tl.y), radius: cornerRadius)
    path.addLine(to: CGPoint(x: tr.x - cornerRadius, y: tr.y))
    path.addArc(tangent1End: CGPoint(x: tr.x, y: tr.y), tangent2End: CGPoint(x: tr.x, y: tr.y - cornerRadius), radius: cornerRadius)
    path.addLine(to: CGPoint(x: br.x, y: br.y + cornerRadius))
    path.addArc(tangent1End: CGPoint(x: br.x, y: br.y), tangent2End: CGPoint(x: br.x - cornerRadius, y: br.y), radius: cornerRadius)

    path.closeSubpath()

    let ret = path.copy()
    return ret!
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

    required init?(coder: NSCoder) {
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
        playback.addObserver(self, forKeyPath: "sourcePos", options: .new, context: nil)
        playback.addObserver(self, forKeyPath: "isPlaying", options: .new, context: nil)
        playback.addObserver(self, forKeyPath: "listenerPos", options: .new, context: nil)
        playback.addObserver(self, forKeyPath: "listenerRotation", options: .new, context: nil)

        playback.checkForMusic()
        self.layoutContents()
    }


//MARK: KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
	// Generally, we just call [self layoutContents] whenever something changes in the oalPlayback environment.
	// When the sound sound source is turned on or off, we also change the image for the speaker to either show
	// or hide the sound waves.

        let obj = object as AnyObject?
        if obj === playback && keyPath == "sourcePos" {
            self.layoutContents()
        } else if obj === playback && keyPath == "isPlaying" {
            self.layoutContents()
            if playback.isPlaying {
                _speakerLayer.contents = _speaker_on
            } else {
                _speakerLayer.contents = _speaker_off
            }
        } else if obj === playback && keyPath == "listenerPos" {
            self.layoutContents()
        } else if obj === playback && keyPath == "listenerRotation" {
            self.layoutContents()
        } else {
            fatalError("\(self) observing unexpected keypath \(keyPath ?? "-") for object \(obj?.debugDescription ?? "nil")")
        }
    }



//MARK: View contents

    func initializeContents() {
	// Load images for the two speaker states and retain them, because we'll be switching between them
        _speaker_off = UIImage(contentsOfFile: Bundle.main.path(forResource: "speaker_off", ofType: "png")!)!.cgImage

        _speaker_on = UIImage(contentsOfFile: Bundle.main.path(forResource: "speaker_on", ofType: "png")!)!.cgImage

        let listenerImg = UIImage(contentsOfFile: Bundle.main.path(forResource: "listener", ofType: "png")!)!.cgImage
        let instructionsImg = UIImage(contentsOfFile: Bundle.main.path(forResource: "instructions", ofType: "png")!)!.cgImage

	// Set up the CALayer which shows the speaker
        _speakerLayer = CALayer()
        _speakerLayer.frame = CGRect(x: 0.0, y: 0.0, width: _speaker_off.width.g, height: _speaker_off.height.g)
        _speakerLayer.contents = _speaker_off

	// Set up the CALayer which shows the listener
        _listenerLayer = CALayer()
        _listenerLayer.frame = CGRect(x: 0.0, y: 0.0, width: (listenerImg?.width.g)!, height: (listenerImg?.height.g)!)
        _listenerLayer.contents = listenerImg
        _listenerLayer.anchorPoint = CGPoint(x: 0.5, y: 0.57)

	// Set up the CALayer which shows the instructions
        _instructionsLayer = CALayer()
        _instructionsLayer.frame = CGRect(x: 0.0, y: 0.0, width: (instructionsImg?.width.g)!, height: (instructionsImg?.height.g)!)
        _instructionsLayer.position = CGPoint(x: 0.0, y: -140.0)
        _instructionsLayer.contents = instructionsImg

	// Set a sublayerTransform on our view's layer. This causes (0,0) to be in the center of the view. This transform
	// is useful because now our view's coordinates map precisely to our oalPlayback sound environment's coordinates.
        let trans = CATransform3DMakeTranslation(self.frame.size.width / 2.0, self.frame.size.height / 2.0, 0.0)
        self.layer.sublayerTransform = trans

	// Set the background image for the sound stage
        let bgImg = UIImage(contentsOfFile: Bundle.main.path(forResource: "stagebg", ofType: "png")!)!.cgImage
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

    private func touchPoint(_ pt: CGPoint) {
        if !_instructionsLayer.isHidden { _instructionsLayer.isHidden = true }

        if _draggingLayer === _speakerLayer { playback.sourcePos = pt }
        else if _draggingLayer === _listenerLayer { playback.listenerPos = pt }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        var pointInView = touches.first!.location(in: self)

	// Clip our pointInView to within 5 pixels of any edge, so we can't position objects near or beyond
	// the edge of the sound stage
        pointInView = CGPointWithinBounds(pointInView, self.bounds.insetBy(dx: 5.0, dy: 5.0))

	// Convert the view point to our layer / sound stage coordinate system, which is centered at (0,0)
        let pointInLayer = CGPoint(x: pointInView.x - self.frame.size.width / 2.0, y: pointInView.y - self.frame.size.height / 2.0)

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

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
	// Called repeatedly as the touch moves

        var pointInView = touches.first!.location(in: self)
        pointInView = CGPointWithinBounds(pointInView, self.bounds.insetBy(dx: 5.0, dy: 5.0))
        let pointInLayer = CGPoint(x: pointInView.x - self.frame.size.width / 2.0, y: pointInView.y - self.frame.size.height / 2.0)
        self.touchPoint(pointInLayer)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        _draggingLayer = nil
    }

    //MARK: ###

    override func layoutSubviews() {
        super.layoutSubviews()
        
        let trans = CATransform3DMakeTranslation(self.frame.size.width / 2.0, self.frame.size.height / 2.0, 0.0)
        self.layer.sublayerTransform = trans
    }
}
