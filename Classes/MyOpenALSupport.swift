//
//  MyOpenALSupport.swift
//  oalTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/3.
//
//
/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
OpenAL-related support functions.
*/

import OpenAL
import AudioToolbox



func MyGetOpenALAudioData(inFileURL: NSURL, inout _ outDataSize: ALsizei, inout _ outDataFormat: ALenum, inout _ outSampleRate: ALsizei) -> UnsafeMutablePointer<Void> {
    var err: OSStatus = noErr
    var theFileLengthInFrames: Int64 = 0
    var theFileFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    var thePropertySize: UInt32 = UInt32(strideofValue(theFileFormat))
    var extRef: ExtAudioFileRef = nil
    var theData: UnsafeMutablePointer<CChar> = nil
    var theOutputFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    
    Exit: do {
        // Open a file with ExtAudioFileOpen()
        err = ExtAudioFileOpenURL(inFileURL, &extRef)
        if err != 0 { print("MyGetOpenALAudioData: ExtAudioFileOpenURL FAILED, Error = \(err)"); break Exit }
        
        // Get the audio data format
        err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &theFileFormat)
        if err != 0 { print("MyGetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat) FAILED, Error = \(err)"); break Exit }
        if theFileFormat.mChannelsPerFrame > 2 { print("MyGetOpenALAudioData - Unsupported Format, channel count is greater than stereo"); break Exit }
        
        // Set the client format to 16 bit signed integer (native-endian) data
        // Maintain the channel count and sample rate of the original source format
        theOutputFormat.mSampleRate = theFileFormat.mSampleRate
        theOutputFormat.mChannelsPerFrame = theFileFormat.mChannelsPerFrame
        
        theOutputFormat.mFormatID = kAudioFormatLinearPCM
        theOutputFormat.mBytesPerPacket = 2 * theOutputFormat.mChannelsPerFrame
        theOutputFormat.mFramesPerPacket = 1
        theOutputFormat.mBytesPerFrame = 2 * theOutputFormat.mChannelsPerFrame
        theOutputFormat.mBitsPerChannel = 16
        theOutputFormat.mFormatFlags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger
        
        // Set the desired client (output) data format
        err = ExtAudioFileSetProperty(extRef, kExtAudioFileProperty_ClientDataFormat, UInt32(strideofValue(theOutputFormat)), &theOutputFormat)
        if err != 0 { print("MyGetOpenALAudioData: ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat) FAILED, Error = \(err)"); break Exit }
        
        // Get the total frame count
        thePropertySize = UInt32(strideofValue(theFileLengthInFrames))
        err = ExtAudioFileGetProperty(extRef, kExtAudioFileProperty_FileLengthFrames, &thePropertySize, &theFileLengthInFrames)
        if err != 0 { print("MyGetOpenALAudioData: ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) FAILED, Error = \(err)"); break Exit }
        
        // Read all the data into memory
        let dataSize = UInt32(theFileLengthInFrames) * theOutputFormat.mBytesPerFrame
        theData = UnsafeMutablePointer.alloc(Int(dataSize))
        if theData != nil {
            var theDataBuffer: AudioBufferList = AudioBufferList()
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
                print("MyGetOpenALAudioData: ExtAudioFileRead FAILED, Error = \(err)"); break Exit;
            }
        }
    }
    
    // Dispose the ExtAudioFileRef, it is no longer needed
    if extRef != nil { ExtAudioFileDispose(extRef) }
    return UnsafeMutablePointer(theData)
}

func MyFreeOpenALAudioData(data: UnsafeMutablePointer<Void>, _ dataSize: ALsizei) {
    let theData = UnsafeMutablePointer<CChar>(data)
    if theData != nil {
        theData.dealloc(Int(dataSize))
    }
}