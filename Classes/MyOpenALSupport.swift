//
//  MyOpenALSupport.swift
//  oalTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/2/8.
//
//
/*

    File: MyOpenALSupport.h
    File: MyOpenALSupport.c
Abstract: OpenAL-related support functions
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

import OpenAL.AL
import AudioToolbox



func MyGetOpenALAudioData(inFileURL: NSURL, inout outDataSize: ALsizei, inout outDataFormat: ALenum, inout outSampleRate: ALsizei) -> UnsafeMutablePointer<Void> {
    var err: OSStatus = noErr
    var theFileLengthInFrames: Int64 = 0
    var theFileFormat: AudioStreamBasicDescription = empty_struct()
    var thePropertySize: UInt32 = UInt32(strideofValue(theFileFormat))
    var extRef: ExtAudioFileRef = nil
    var theData: UnsafeMutablePointer<CChar> = nil
    var theOutputFormat: AudioStreamBasicDescription = empty_struct()
    
    Exit: do {
        // Open a file with ExtAudioFileOpen()
        err = ExtAudioFileOpenURL(inFileURL, &extRef)
        if err != 0 { println("MyGetOpenALAudioData: ExtAudioFileOpenURL FAILED, Error = \(err)"); break Exit }
        
        // Get the audio data format
        err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileDataFormat.ui, &thePropertySize, &theFileFormat)
        if err != 0 { println("MyGetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat) FAILED, Error = \(err)"); break Exit }
        if theFileFormat.mChannelsPerFrame > 2 { println("MyGetOpenALAudioData - Unsupported Format, channel count is greater than stereo"); break Exit }
        
        // Set the client format to 16 bit signed integer (native-endian) data
        // Maintain the channel count and sample rate of the original source format
        theOutputFormat.mSampleRate = theFileFormat.mSampleRate
        theOutputFormat.mChannelsPerFrame = theFileFormat.mChannelsPerFrame
        
        theOutputFormat.mFormatID = kAudioFormatLinearPCM.ui
        theOutputFormat.mBytesPerPacket = 2 * theOutputFormat.mChannelsPerFrame
        theOutputFormat.mFramesPerPacket = 1
        theOutputFormat.mBytesPerFrame = 2 * theOutputFormat.mChannelsPerFrame
        theOutputFormat.mBitsPerChannel = 16
        theOutputFormat.mFormatFlags = kAudioFormatFlagsNativeEndian.ui | kAudioFormatFlagIsPacked.ui | kAudioFormatFlagIsSignedInteger.ui
        
        // Set the desired client (output) data format
        err = ExtAudioFileSetProperty(extRef, kExtAudioFileProperty_ClientDataFormat.ui, UInt32(strideofValue(theOutputFormat)), &theOutputFormat)
        if err != 0 { println("MyGetOpenALAudioData: ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat) FAILED, Error = \(err)"); break Exit }
        
        // Get the total frame count
        thePropertySize = UInt32(strideofValue(theFileLengthInFrames))
        err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileLengthFrames.ui, &thePropertySize, &theFileLengthInFrames)
        if err != 0 { println("MyGetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) FAILED, Error = \(err)"); break Exit }
        
        // Read all the data into memory
        let dataSize = UInt32(theFileLengthInFrames) * theOutputFormat.mBytesPerFrame
        theData = UnsafeMutablePointer.alloc(Int(dataSize))
        if theData != nil {
            var theDataBuffer: AudioBufferList = empty_struct()
            theDataBuffer.mNumberBuffers = 1
            theDataBuffer.mBuffers.mDataByteSize = dataSize
            theDataBuffer.mBuffers.mNumberChannels = theOutputFormat.mChannelsPerFrame
            theDataBuffer.mBuffers.mData = UnsafeMutablePointer(theData)
            
            // Read the data into an AudioBufferList
            var ioNumberFrames: UInt32 = UInt32(theFileLengthInFrames)
            err = ExtAudioFileRead(extRef, &ioNumberFrames, &theDataBuffer)
            if err == noErr {
                // success
                outDataSize = ALsizei(dataSize)
                outDataFormat = (theOutputFormat.mChannelsPerFrame > 1) ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16
                outSampleRate = ALsizei(theOutputFormat.mSampleRate)
            } else {
                // failure
                theData.dealloc(Int(dataSize))
                theData = nil // make sure to return NULL
                println("MyGetOpenALAudioData: ExtAudioFileRead FAILED, Error = \(err)"); break Exit;
            }
        }
    } while false
    
    // Dispose the ExtAudioFileRef, it is no longer needed
    if extRef != nil { ExtAudioFileDispose(extRef) }
    return UnsafeMutablePointer(theData)
}

func MyFreeOpenALAudioData(data: UnsafeMutablePointer<Void>, dataSize: ALsizei) {
    let theData = UnsafeMutablePointer<CChar>(data)
    if theData != nil {
        theData.dealloc(Int(dataSize))
    }
}