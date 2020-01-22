//
//  AVStreamManager+EventHandler.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/22.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import Foundation

extension AVStreamManager {
    
    func registerNotifications() {
                
        NotificationCenter.default.addObserver(self, selector: #selector(onSessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(onSessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: nil)
    }
    
    
    @objc
    func onSessionWasInterrupted(notification: NSNotification) {
        NSLog("\(#function)")
    }
    @objc
    func onSessionInterruptionEnded(notification: NSNotification) {
        NSLog("\(#function)")
    }
}
