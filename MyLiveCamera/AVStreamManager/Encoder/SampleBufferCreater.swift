//
//  SampleBufferCreater.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/27.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import Foundation
import AVFoundation

class SampleBufferCreater {
    
    static func buildForVideo(with imageBuffer: CVPixelBuffer, numberOfSamples: CMItemCount, timeInfo: CMSampleTimingInfo) -> CMSampleBuffer? {
                
        var status: OSStatus
        // Init Video Format
        var videoFormatNullable: CMVideoFormatDescription? = nil
        status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: imageBuffer, formatDescriptionOut: &videoFormatNullable)
            
                      
        guard let videoFormat = videoFormatNullable else { return nil }
        var sampleTiming = timeInfo
        var sampleBufferNullable: CMSampleBuffer? = nil
        status = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: imageBuffer, formatDescription: videoFormat, sampleTiming: &sampleTiming, sampleBufferOut: &sampleBufferNullable)
         
        if status != noErr {
            return nil
        }
        return sampleBufferNullable
    }
    
    static func buildForAudio(with binaryData: NSData, description: CMFormatDescription, numberOfSamples: CMItemCount, timeInfo: CMSampleTimingInfo) -> CMSampleBuffer? {
        
        guard binaryData.length > 0 else { return nil }
        
        var status: OSStatus
        // Init Memory Block
        var blockBufferNullable: CMBlockBuffer? = nil
        status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                    memoryBlock: nil,
                                                    blockLength: binaryData.length,
                                                    blockAllocator: kCFAllocatorDefault,
                                                    customBlockSource: nil,
                                                    offsetToData: 0,
                                                    dataLength: binaryData.length,
                                                    flags: kCMBlockBufferAssureMemoryNowFlag,
                                                    blockBufferOut: &blockBufferNullable);
        
        guard let blockBuffer = blockBufferNullable else { return nil }
        status = CMBlockBufferReplaceDataBytes(with: binaryData.bytes,
                                               blockBuffer: blockBuffer,
                                               offsetIntoDestination: 0,
                                               dataLength: binaryData.length);
                                       
        // Init Sample Buffer
        var sampleBufferNullable: CMSampleBuffer? = nil
        var sampleTimingArray = timeInfo
        var sampleSizeArray = numberOfSamples
        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                      dataBuffer: blockBuffer,
                                      dataReady: true,
                                      makeDataReadyCallback: nil,
                                      refcon: nil,
                                      formatDescription: description,
                                      sampleCount: numberOfSamples,
                                      sampleTimingEntryCount: 1,
                                      sampleTimingArray: &sampleTimingArray,
                                      sampleSizeEntryCount: 1,
                                      sampleSizeArray: &sampleSizeArray,
                                      sampleBufferOut: &sampleBufferNullable);
        if status != noErr {
            return nil
        }
        return sampleBufferNullable
    }
}
