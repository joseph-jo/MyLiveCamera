//
//  LiveStreamWorker.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/23.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import Foundation
import AVFoundation

class LiveStreamWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    var videoDataOutput = AVCaptureVideoDataOutput()
    var audioDataOutput = AVCaptureAudioDataOutput()
    var liveStreamDataQueue = DispatchQueue(label: "liveStreamDataQueue")
    
    var videoEncoder: H264Encoder!
    var audioEncoder: AudioEncoder!
    var running: Bool { return recording || encoding }
    var recording = false
    private(set) var encoding = false
    
    override init() {
        super.init()
        
        videoDataOutput.setSampleBufferDelegate(self, queue: liveStreamDataQueue)
        audioDataOutput.setSampleBufferDelegate(self, queue: liveStreamDataQueue)
    }
    
}

extension LiveStreamWorker {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
               
//        guard encoding != false else { return }
        
        // Video
        if output == videoDataOutput {
            
            guard let imageBuffer = sampleBuffer.getCVImageBuffer() else { return }
            let videoSize = imageBuffer.getDisplaySize()
            
            if videoEncoder == nil {
                videoEncoder = H264Encoder.init(videoSize: videoSize)
            }
                        
            videoEncoder.encode(with: sampleBuffer, streamingHandler: { (binaryData, timestamp) in
                            
//                NSLog("video: \(timestamp): \(binaryData.length)")
            }, sampleBufferHandler: {
                            (encodedBuffer) in
                            
//                NSLog("video: \(encodedBuffer)")
            })
        }
            
        // Audio
        else if output == audioDataOutput {
            
            if audioEncoder == nil {
                audioEncoder = AudioEncoder(to: 8000, codec: .uLaw)
            }
            audioEncoder.encode(with: sampleBuffer, streamingHandler: { (binaryData, timestamp) in
                
//                NSLog("audio: \(timestamp): \(binaryData.length)")
            }, sampleBufferHandler: {
                (encodedBuffer) in
                
//                NSLog("audio: \(encodedBuffer)")
            })
        }
    }
}
