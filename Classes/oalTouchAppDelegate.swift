//
//  oalTouchAppDelegate.swift
//  oalTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/3.
//
//
/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
pp delegate. Ties everything together, and handles some high-level UI input.
*/

import UIKit
import CoreMotion

@UIApplicationMain
@objc(oalTouchAppDelegate)
class oalTouchAppDelegate: NSObject, UIApplicationDelegate, UIAccelerometerDelegate {
    var window: UIWindow?
    @IBOutlet var view: oalSpatialView!
    @IBOutlet var playback: oalPlayback!
    private var motionManager: CMMotionManager!
    
    @IBOutlet var viewController: UIViewController!
    
    
    func applicationDidFinishLaunching(application: UIApplication) {
        
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        self.window?.rootViewController = self.viewController
        self.window?.makeKeyAndVisible()
        
        // Get accelerometer updates at 15 hz
        motionManager = CMMotionManager()
        motionManager.accelerometerUpdateInterval = (1.0 / 15.0)
    }
    
    deinit {
        motionManager?.stopAccelerometerUpdates()
    }
    
    
    @IBAction func playPause(sender: UIButton) {
        // Toggle the playback
        
        if playback.isPlaying {
            playback.stopSound()
        } else {
            playback.startSound()
        }
        sender.selected = playback.isPlaying
    }
    
    @IBAction func toggleAccelerometer(sender: UISwitch) {
        // Toggle the accelerometer
        // Note: With the accelerometer on, the device should be held vertically, not laid down flat.
        // As the device is rotated, the orientation of the listener will adjust so as as to be looking upward.
        if sender.on {
            motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue()) {data, error in
                dispatch_async(dispatch_get_main_queue()) {
                    
                    // Find out the Z rotation of the device by doing some trig on the accelerometer values for X and Y
                    let zRot  = CGFloat(atan2(data.acceleration.x, data.acceleration.y) + M_PI)
                    
                    // Set our listener's rotation
                    self.playback.listenerRotation = zRot
                }
            }
        } else {
            motionManager.stopAccelerometerUpdates()
        }
    }
    
}