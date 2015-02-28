//
//  oalPlayback.swift
//  oalTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/2/8.
//
//
/*

    File: oalPlayback.h
    File: oalPlayback.m
Abstract: An Obj-C class which wraps an OpenAL playback environment
 Version: 1.9

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2010 Apple Inc. All Rights Reserved.


 */

import UIKit
import AVFoundation

import OpenAL.AL
import OpenAL.ALC
typealias ALCcontext = COpaquePointer
typealias ALCdevice = COpaquePointer

let kDefaultDistance: Float = 25.0

@objc(oalPlayback)
class oalPlayback: NSObject {
    @IBOutlet var musicSwitch: UISwitch!
    
    var source: ALuint = 0
    var buffer: ALuint = 0
    var context: ALCcontext = nil
    var device: ALCdevice = nil
    
    var data: UnsafeMutablePointer<Void> = nil
    var sourceVolume: ALfloat = 0
    // Whether the sound is playing or stopped
    dynamic var isPlaying: Bool = false
    // Whether playback was interrupted by the system
    var wasInterrupted: Bool = false
    
    var bgURL: NSURL!
    var bgPlayer: AVAudioPlayer?
    // Whether the iPod is playing
    var iPodIsPlaying: Bool = false
    
    
    //MARK: Object Init / Maintenance
    private weak var interruptionObserver: NSObjectProtocol? = nil
    private func interruptionHandler(notification: NSNotification!) {
        let rawInterruptionType = notification.userInfo![AVAudioSessionInterruptionTypeKey]! as! UInt
        if let interruptionType = AVAudioSessionInterruptionType(rawValue: rawInterruptionType) {
            if interruptionType == .Began {
                alcMakeContextCurrent(nil)
                if self.isPlaying {
                    self.wasInterrupted = true
                }
            } else if interruptionType == .Ended {
                let session = AVAudioSession.sharedInstance()
                var error: NSError? = nil
                let success = session.setActive(true, error: &error)
                if !success { NSLog("Error setting audio session active! %@\n", error!) }
                
                alcMakeContextCurrent(self.context)
                
                if self.wasInterrupted {
                    self.startSound()
                    self.wasInterrupted = false
                }
            }
        }
    }
    
    private weak var routeChangeObserver: NSObjectProtocol? = nil
    private func RouteChangeHandler(notification: NSNotification!) {
        
        let oldRouteDescription = notification.userInfo![AVAudioSessionRouteChangePreviousRouteKey]! as! AVAudioSessionRouteDescription
        let oldRoute = oldRouteDescription.description
        
        let session = AVAudioSession.sharedInstance()
        let newRouteDescription = session.currentRoute
        let newRoute = newRouteDescription.description
        
        NSLog("Route changed from %@ to %@", oldRoute, newRoute)
    }
    
    override init() {
        super.init()
        // Start with our sound source slightly in front of the listener
        self._sourcePos = CGPointMake(0.0, -70.0)
        
        // Put the listener in the center of the stage
        self._listenerPos = CGPointMake(0.0, 0.0)
        
        // Listener looking straight ahead
        self._listenerRotation = 0.0
        
        // setup our audio session
        let session = AVAudioSession.sharedInstance()
        var error: NSError? = nil
        if session == nil {
            NSLog("Error initializing audio session!\n")
        } else {
            let notificationCenter = NSNotificationCenter.defaultCenter()
            interruptionObserver = notificationCenter.addObserverForName(AVAudioSessionInterruptionNotification, object: session, queue: nil, usingBlock: interruptionHandler)
            // if there is other audio playing, we don't want to play the background music
            self.iPodIsPlaying = session.otherAudioPlaying
            
            // if the iPod is playing, use the ambient category to mix with it
            // otherwise, use solo ambient to get the hardware for playing the app background track
            let category: String = iPodIsPlaying ? AVAudioSessionCategoryAmbient : AVAudioSessionCategorySoloAmbient
            
            var success = session.setCategory(category, error: &error)
            if !success { NSLog("Error setting audio session category! %@\n", error!) }
            
            routeChangeObserver = notificationCenter.addObserverForName(AVAudioSessionRouteChangeNotification, object: session, queue: nil, usingBlock: RouteChangeHandler)
            
            success = session.setActive(true, error: &error)
            if !success { NSLog("Error setting audio session active! %@\n", error!) }
        }
        
        bgURL = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("background", ofType: "m4a")!)!
        bgPlayer = AVAudioPlayer(contentsOfURL: bgURL, error: &error)
        
        wasInterrupted = false
        
        // Initialize our OpenAL environment
        self.initOpenAL()
        
    }
    
    func checkForMusic() {
        if iPodIsPlaying {
            //the iPod is playing, so we should disable the background music switch
            NSLog("Disabling background music, iPod is active")
            musicSwitch.enabled = false
        } else {
            musicSwitch.enabled = true
        }
    }
    
    deinit {
        let session = AVAudioSession.sharedInstance()
        let notificationCenter = NSNotificationCenter.defaultCenter()
        if interruptionObserver != nil {
            notificationCenter.removeObserver(interruptionObserver!, name: AVAudioSessionInterruptionNotification, object: session)
        }
        if routeChangeObserver != nil {
            notificationCenter.removeObserver(routeChangeObserver!, name: AVAudioSessionRouteChangeNotification, object: session)
        }
        
        self.teardownOpenAL()
    }
    
    //MARK: AVAudioPlayer
    
    @IBAction func toggleMusic(sender: UISwitch) {
        NSLog("toggling music %@", sender.on ? "on" : "off")
        
        if bgPlayer != nil {
            
            if sender.on {
                bgPlayer?.play()
            } else {
                bgPlayer?.stop()
            }
        }
    }
    
    //MARK: OpenAL
    
    private func initBuffer() {
        var format: ALenum = 0
        var size: ALsizei = 0
        var freq: ALsizei = 0
        
        let bundle = NSBundle.mainBundle()
        
        // get some audio data from a wave file
        let fileURL = NSURL(fileURLWithPath: bundle.pathForResource("sound", ofType: "caf")!)
        
        if fileURL != nil {
            data = MyGetOpenALAudioData(fileURL!, &size, &format, &freq)
            
            var error = alGetError()
            if error != AL_NO_ERROR {
                fatalError("error loading sound: \(error)\n")
            }
            
            // use the static buffer data API
            alBufferData(buffer, format, data, size, freq)
            MyFreeOpenALAudioData(data, size)
            
            error = alGetError()
            if error != AL_NO_ERROR {
                NSLog("error attaching audio to buffer: \(error)\n")
            }
        } else {
            NSLog("Could not find file!\n")
        }
    }
    
    private func initSource() {
        var error: ALenum = AL_NO_ERROR
        alGetError() // Clear the error
        
        // Turn Looping ON
        alSourcei(source, AL_LOOPING, AL_TRUE)
        
        // Set Source Position
        let sourcePosAL: [Float] = [Float(sourcePos.x), kDefaultDistance, Float(sourcePos.y)]
        alSourcefv(source, AL_POSITION, sourcePosAL)
        
        // Set Source Reference Distance
        alSourcef(source, AL_REFERENCE_DISTANCE, 50.0)
        
        // attach OpenAL Buffer to OpenAL Source
        alSourcei(source, AL_BUFFER, ALint(buffer))
        
        error = alGetError()
        if error != AL_NO_ERROR {
            fatalError("Error attaching buffer to source: \(error)\n")
        }
    }
    
    
    func initOpenAL() {
        var error: ALenum = AL_NO_ERROR
        
        // Create a new OpenAL Device
        // Pass NULL to specify the system’s default output device
        device = alcOpenDevice(nil)
        if device != nil {
            // Create a new OpenAL Context
            // The new context will render to the OpenAL Device just created
            context = alcCreateContext(device, nil)
            if context != nil {
                // Make the new context the Current OpenAL Context
                alcMakeContextCurrent(context)
                
                // Create some OpenAL Buffer Objects
                alGenBuffers(1, &buffer)
                error = alGetError()
                if error != AL_NO_ERROR {
                    fatalError("Error Generating Buffers: \(error)")
                }
                
                // Create some OpenAL Source Objects
                alGenSources(1, &source)
                if alGetError() != AL_NO_ERROR {
                    fatalError("Error generating sources! \(error)\n")
                }
                
            }
        }
        // clear any errors
        alGetError()
        
        self.initBuffer()
        self.initSource()
    }
    
    func teardownOpenAL() {
        // Delete the Sources
        alDeleteSources(1, &source)
        // Delete the Buffers
        alDeleteBuffers(1, &buffer)
        
        //Release context
        alcDestroyContext(context)
        //Close device
        alcCloseDevice(device)
    }
    
    //MARK: Play / Pause
    
    func startSound() {
        var error: ALenum = AL_NO_ERROR
        
        NSLog("Start!\n")
        // Begin playing our source file
        alSourcePlay(source)
        error = alGetError()
        if error != AL_NO_ERROR {
            NSLog("error starting source: %x\n", error)
        } else {
            // Mark our state as playing (the view looks at this)
            self.isPlaying = true
        }
    }
    
    func stopSound() {
        var error: ALenum = AL_NO_ERROR
        
        NSLog("Stop!!\n")
        // Stop playing our source file
        alSourceStop(source)
        error = alGetError()
        if error != AL_NO_ERROR {
            NSLog("error stopping source: %x\n", error)
        } else {
            // Mark our state as not playing (the view looks at this)
            self.isPlaying = false
        }
    }
    
    //MARK: Setters / Getters
    
    // The coordinates of the sound source
    private var _sourcePos: CGPoint = CGPoint()
    dynamic var sourcePos: CGPoint {
        get {
            return self._sourcePos
        }
        
        set(SOURCEPOS) {
            self._sourcePos = SOURCEPOS
            let sourcePosAL: [Float] = [Float(self._sourcePos.x), kDefaultDistance, Float(self._sourcePos.y)]
            // Move our audio source coordinates
            alSourcefv(source, AL_POSITION, sourcePosAL)
        }
    }
    
    
    
    // The coordinates of the listener
    private var _listenerPos: CGPoint = CGPoint()
    dynamic var listenerPos: CGPoint {
        get {
            return self._listenerPos
        }
        
        set(LISTENERPOS) {
            self._listenerPos = LISTENERPOS
            let listenerPosAL: [Float] = [Float(self._listenerPos.x), 0.0, Float(self._listenerPos.y)]
            // Move our listener coordinates
            alListenerfv(AL_POSITION, listenerPosAL)
        }
    }
    
    
    
    // The rotation angle of the listener in radians
    private var _listenerRotation: CGFloat = 0
    dynamic var listenerRotation: CGFloat {
        get {
            return self._listenerRotation
        }
        
        set(radians) {
            self._listenerRotation = radians
            let ori: [Float] = [Float(cos(radians + M_PI_2.g)), Float(sin(radians + M_PI_2.g)), 0.0, 0.0, 0.0, 1.0]
            
            // Set our listener orientation (rotation)
            alListenerfv(AL_ORIENTATION, ori)
        }
    }
    
}