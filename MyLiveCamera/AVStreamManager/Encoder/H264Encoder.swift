//
//  H264Encoder.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/23.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import UIKit
import VideoToolbox

class H264Encoder: NSObject {

    let h264EncodeQueue = DispatchQueue(label: "h264EncodeQueue")
    var sessionCompression: VTCompressionSession?
    
    var videoWidth: Int32 = 0
    var videoHeight: Int32 = 0
    
    init(videoSize: CGSize) {
        super.init()
        self.setupEncoder(videoSize: videoSize)
    }
    
    func setupEncoder(videoSize: CGSize) {

         let unmanagedSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
         videoWidth = Int32(videoSize.width)
         videoHeight = Int32(videoSize.height)
         let status = VTCompressionSessionCreate(allocator: nil, width: videoWidth, height: videoHeight, codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: outputCallback, refcon:unmanagedSelf, compressionSessionOut: &(sessionCompression))
        
        guard status == 0 else { return }
        guard let session = sessionCompression else { return }
        
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)

        var maxKeyframeInterval = 10
        let maxKeyframeIntervalRef = CFNumberCreate(kCFAllocatorDefault, .intType, &maxKeyframeInterval);
         VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: maxKeyframeIntervalRef)
        
        var averageBitRate = 512 * 1024 // 512 K bits/sec
        let averageBitRateRef = CFNumberCreate(kCFAllocatorDefault, .intType, &averageBitRate);
         VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: averageBitRateRef)
                  
        VTCompressionSessionPrepareToEncodeFrames(session)
    }
}

func outputCallback(outputCallbackRefCon: UnsafeMutableRawPointer?, sourceFrameRefCon: UnsafeMutableRawPointer?,status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?)
{
    guard let sampleBuffer = sampleBuffer else { return }
    guard let h264Encoder = sourceFrameRefCon else { return }
    let scopedSelf = Unmanaged<H264Encoder>.fromOpaque(h264Encoder).takeUnretainedValue()

    guard let (binaryData, timestamp) = H264Encoder.getBinaryData(with:sampleBuffer) else { return }
    
    NSLog("\(timestamp): \(binaryData.length)")
}

extension H264Encoder {
   
    func encode(with sampleBuffer: CMSampleBuffer) {
        
        h264EncodeQueue.async {

            guard let session = self.sessionCompression else { return }
            guard let imageBuffer = sampleBuffer.getCVImageBuffer() else { return }
        
            let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                       
            let unmanagedSelf = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            
            var status : OSStatus
            status = VTCompressionSessionEncodeFrame(session, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, duration: CMTime.invalid, frameProperties: nil, sourceFrameRefcon: unmanagedSelf, infoFlagsOut: nil)
            if (status != noErr) {
                NSLog("An Error occured while compress the frame")
            }
        }
    }
}


extension H264Encoder {

    static func getBinaryData(with sampleBuffer: CMSampleBuffer) -> (NSData, CMTime)? {
        
        var outputArray = [NSData]()
        
        guard let attachmentArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as NSArray? else { return nil }
        
        guard let attachment = attachmentArray[0] as? NSDictionary else { return nil }
        
        var isKeyFrame = false
        if let depends = attachment[kCMSampleAttachmentKey_DependsOnOthers] as? NSNumber {
            if !depends.boolValue {
                isKeyFrame = true
            }
        }
        NSLog("\(isKeyFrame)")
        
        if isKeyFrame {
            
            guard let keyFrameHeader = H264Encoder.getKeyFrameHeader(sampleBuffer: sampleBuffer) else { return nil }
            
            outputArray.append(keyFrameHeader)
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        
        var length: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>? = nil

        var status : OSStatus
        status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
        guard status == noErr, let dataPointerUnwrapped = dataPointer else { return nil }
    
        let AVCCHeaderLength = 4
        var bufferOffset: size_t = 0
        while bufferOffset < totalLength - AVCCHeaderLength {
            var NALUnitLength: UInt32  = 0
             
            memcpy(&NALUnitLength, dataPointerUnwrapped + bufferOffset, AVCCHeaderLength);
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            let data = NSData(bytes: dataPointerUnwrapped + bufferOffset + AVCCHeaderLength, length: Int(NALUnitLength))
            
            outputArray.append(data)
            bufferOffset = bufferOffset + AVCCHeaderLength + Int(NALUnitLength)
                        
        }
        
        let ret = NSMutableData()
        for data in outputArray {
            ret.append(data as Data)
        }
        
        let timeP = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        return (ret, timeP)
    }
        
    static func getKeyFrameHeader(sampleBuffer: CMSampleBuffer) -> NSData? {
        
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }

        var sps: UnsafePointer<UInt8>? = nil

        var pps: UnsafePointer<UInt8>? = nil
        var spsLength: Int = 0
        var ppsLength: Int = 0
        var spsCount: Int = 0
        var ppsCount: Int = 0

        var status : OSStatus
        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 0, parameterSetPointerOut: &sps, parameterSetSizeOut: &spsLength, parameterSetCountOut: &spsCount, nalUnitHeaderLengthOut: nil )
        if (status != noErr) {
            NSLog("An Error occured while getting h264 parameter")
        }

        status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: 1, parameterSetPointerOut: &pps, parameterSetSizeOut: &ppsLength, parameterSetCountOut: &ppsCount, nalUnitHeaderLengthOut: nil )
        if (status != noErr) {
            NSLog("An Error occured while getting h264 parameter")
        }
         
        let spsBinaryData = NSData(bytes: sps, length: spsCount)
        let ppsBinaryData = NSData(bytes: pps, length: ppsCount)
                
        var naluStartPattern:[UInt8] = [0x00, 0x00, 0x00, 0x01]
        let naluStartHeaderData = NSData(bytes: &naluStartPattern, length: 4)
        
        let ret = NSMutableData()
        for data in [naluStartHeaderData, spsBinaryData, naluStartHeaderData, ppsBinaryData] {
            ret.append(data as Data)
        }
        return ret
    }
}
