//
//  MainVideoViewController+EventHandler.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/22.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import Foundation
import AVFoundation

extension MainVideoViewContorller {
    
    func registerNotifications() {
                
        NotificationCenter.default.addObserver(self, selector: #selector(onSessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: nil)
    }
    
    @objc
    func onSessionRuntimeError(notification: NSNotification) {
        NSLog("\(#function)")
        
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        NSLog("Capture session runtime error: \(error)")
        // If media services were reset, and the last start succeeded, restart the session.
        if error.code == .mediaServicesWereReset {
            self.startRunning()
        }
    }
}
