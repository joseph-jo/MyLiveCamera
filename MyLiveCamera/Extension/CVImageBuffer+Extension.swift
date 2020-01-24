//
//  CVImageBuffer+Extension.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/23.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import Foundation
import AVFoundation

extension CVImageBuffer {
    
    func getDisplaySize() -> CGSize {
        
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags())
        
        let size = CVImageBufferGetDisplaySize(self)
        
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags())
        
        return size
    }
}
