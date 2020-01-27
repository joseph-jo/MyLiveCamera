//
//  Resampler.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/25.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import UIKit
import AVFoundation

class Resampler: NSObject {

    let resampleQueue = DispatchQueue(label: "resampleQueue")
    var audioConverter: AudioConverterRef?
    var dataPool = MyBuffer(count: Int(outBufferSize * 10))
    var srcDesc: AudioStreamBasicDescription? = nil
    var destDesc: AudioStreamBasicDescription? = nil
    var destSampleRate: Float64 = 0
    var debugFileHandle: FileHandle? = nil
    var onStreamingHandler: ((NSData, CMTime) -> Void)?
    var onSampleBufferHandler: ((CMSampleBuffer) -> Void)?
    
    static let outBufferSize: UInt32 = 2048
    
    init(to sampleRate: Float64) {
        super.init()
        destSampleRate = sampleRate
//        debugFileHandle = self.initFileHandle(fileName: "audio.pcm")
    }
        
    func setupAudioConverter(with sampleBuffer: CMSampleBuffer) -> AudioConverterRef? {
        
        if self.audioConverter != nil { return self.audioConverter }
        
        guard destSampleRate > 0 else { return nil }
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        guard let descPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return nil }
        self.srcDesc = descPtr.pointee
        var destDesc = self.srcDesc!
        
        var status: OSStatus
        var audioConverter: AudioConverterRef?
        destDesc.mSampleRate = destSampleRate
        self.destDesc = destDesc
        
        status = AudioConverterNew(descPtr, &destDesc, &audioConverter)
        if status != noErr {
            return nil
        }
                 
        return audioConverter
    }
}
 
extension Resampler {
    
    func resample(with sampleBuffer: CMSampleBuffer, streamingHandler: @escaping (NSData, CMTime) -> Void, sampleBufferHandler: @escaping (CMSampleBuffer) -> Void ) {
        
        self.onStreamingHandler = streamingHandler
        self.onSampleBufferHandler = sampleBufferHandler
        
        audioConverter = self.setupAudioConverter(with: sampleBuffer)
        
        resampleQueue.async {
            
            guard let audioConverterUnwrap = self.audioConverter else { return }
            
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
            let timeP = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        
            let resampledData = NSMutableData()
            var lengthAtOffset: Int = 0
            var totalLength: Int = 0
            var dataPointer: UnsafeMutablePointer<Int8>? = nil
            
            var status: OSStatus
            status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
            if status != kCMBlockBufferNoErr {
                _ = NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
            }
                        
            let sampleData = NSData.init(bytes: dataPointer, length: totalLength)
            self.dataPool.write(sampleData)
                                  
            // ---
            repeat {
                
                var packetSize: UInt32 = 1
                let mDataBuffer = UnsafeMutableRawPointer.allocate(byteCount: Int(Resampler.outBufferSize), alignment: 0)
                defer {
                    mDataBuffer.deallocate()
                }
                
                var outAudioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: Resampler.outBufferSize, mData: mDataBuffer))
              
                let unmanagedSelf = Unmanaged.passUnretained(self).toOpaque()
              
                status = AudioConverterFillComplexBuffer(audioConverterUnwrap, resamplerOutputCallback, unmanagedSelf, &packetSize, &outAudioBufferList, nil)
               
                switch status {
                case noErr:
                    guard let outBuf = outAudioBufferList.mBuffers.mData else { continue }
                    resampledData.append(Data(bytes:outBuf, count: Int(outAudioBufferList.mBuffers.mDataByteSize)))
                case -1:
//                    print("data end")
                    break
                default:
                    // Error
                    break
                }
                
            } while status == noErr
                         
            self.dataPool.resetAll()
            
            // Output 1
            self.debugFileHandle?.write(resampledData as Data)
            
            // Output 2
            self.onStreamingHandler?(resampledData, CMTime(value: timeP.value, timescale: CMTimeScale(self.destSampleRate)))
            
            // Output 3
            let sampleBufferNullable = self.buildSampleBuffer(with: resampledData, timestamp: timeP)
            guard let resampledBuffer = sampleBufferNullable else { return }
            self.onSampleBufferHandler?(resampledBuffer)
        }
    }
}

extension Resampler {
    
    func initFileHandle(fileName: String) -> FileHandle? {
        
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) as NSURL else {
            return nil
        }
        guard let filepath = directory.appendingPathComponent(fileName) else { return nil }
        
        do {
            try FileManager.default.removeItem(atPath: filepath.absoluteString)
        }
        catch {
            
        }
        let _ = FileManager.default.createFile(atPath: filepath.path, contents: nil, attributes: nil)
        
        var fileHandle: FileHandle? = nil
        fileHandle = FileHandle.init(forWritingAtPath: filepath.path)
                
        return fileHandle
    }
}

func resamplerOutputCallback(inAudioConverter: AudioConverterRef, ioNumberDataPackets: UnsafeMutablePointer<UInt32>, ioData: UnsafeMutablePointer<AudioBufferList>, outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?, inUserData: UnsafeMutableRawPointer?) -> OSStatus
{
    let scopedSelf = Unmanaged<Resampler>.fromOpaque(inUserData!).takeUnretainedValue()
     
    var srcBytesPerPacket: Int = 2   // 1 packet: 2bytes
    if scopedSelf.srcDesc != nil && scopedSelf.srcDesc!.mBytesPerPacket > 0 {
        srcBytesPerPacket = Int(scopedSelf.srcDesc!.mBytesPerPacket)
    }
    let requestedPackets = Int(ioNumberDataPackets.pointee)
    let requestedDataSize = requestedPackets * srcBytesPerPacket
    
    if scopedSelf.dataPool.isAvailableDataForReading(count: requestedDataSize) {
 
        let copiedData = scopedSelf.dataPool.read(length: requestedDataSize)
         
        let ptrBytes = UnsafeMutableRawPointer.allocate(byteCount: copiedData.length, alignment: 0)
        defer {
            ptrBytes.deallocate()
        }
        copiedData.getBytes(ptrBytes, length: copiedData.length)
        
        ioData.pointee.mNumberBuffers = 1
        ioData.pointee.mBuffers.mData = ptrBytes
        ioData.pointee.mBuffers.mDataByteSize = UInt32(copiedData.length)
                
        ioNumberDataPackets.pointee = UInt32(copiedData.length / 2)
    }
    else {
        return -1
    }
         
    return noErr;
}


extension Resampler {
    
    func buildSampleBuffer(with binaryData: NSData, timestamp: CMTime) -> CMSampleBuffer? {
         
         var audioFormat = self.destDesc!
         var audioCMAudioFormatDescNullable: CMAudioFormatDescription? = nil
         CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                        asbd: &audioFormat,
                                        layoutSize: 0,
                                        layout: nil,
                                        magicCookieSize: 0,
                                        magicCookie: nil,
                                        extensions: nil,
                                        formatDescriptionOut: &audioCMAudioFormatDescNullable
                                        );
        
         let audioSampleTimingInformation = CMSampleTimingInfo(duration: CMTimeMake(value: 1, timescale: Int32(8000.0)), presentationTimeStamp: timestamp, decodeTimeStamp: CMTime.invalid)
         
         guard let audioCMAudioFormatDesc = audioCMAudioFormatDescNullable else { return nil }
         let newSampleBuffer = SampleBufferCreater.buildForAudio(with: binaryData, description: audioCMAudioFormatDesc, numberOfSamples: 1, timeInfo: audioSampleTimingInformation)
         
        return newSampleBuffer
    }
}
