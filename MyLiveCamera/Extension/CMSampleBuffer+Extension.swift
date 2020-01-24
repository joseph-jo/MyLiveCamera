//
//  CMSampleBuffer+Extension.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/23.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import Foundation
import AVFoundation

extension CMSampleBuffer {
    
    func getCVImageBuffer() -> CVImageBuffer? {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(self)
        return imageBuffer
    }
}
