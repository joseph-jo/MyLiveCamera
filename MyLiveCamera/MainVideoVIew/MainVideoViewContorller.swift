//
//  MainVideoViewContorller.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/21.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import UIKit
import AVFoundation

class MainVideoViewContorller: UIViewController {
            
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.registerNotifications()

        self.previewLayer.frame = self.view.frame
        self.previewLayer.session = AVStreamManager.manager.sessionCapture
        self.previewLayer.videoGravity = .resizeAspect
        self.view.layer.addSublayer(self.previewLayer)
        
        self.startRunning()
    }
    
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if let videoPreviewLayerConnection = self.previewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue),
                deviceOrientation.isLandscape else { return }
            
            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }
}
extension MainVideoViewContorller {
    
    func startRunning() {
        AVStreamManager.manager.startRunning(completionHandler: { result in
            
            if result != .success {
                NSLog("UI warning for not authorized")
            }

            self.setupVideoOrientation(forLayer: self.previewLayer)
        })
    }
}

extension MainVideoViewContorller {
    
    func setupVideoOrientation(forLayer layer: AVCaptureVideoPreviewLayer) {
        
        var initialVideoOrientation: AVCaptureVideoOrientation = .landscapeRight
        
        guard let windowOrientation = view.window?.windowScene?.interfaceOrientation, windowOrientation != .unknown else { return }
        
        guard let videoOrientation = AVCaptureVideoOrientation(rawValue: windowOrientation.rawValue) else { return }
        guard initialVideoOrientation != videoOrientation else { return }
        
        initialVideoOrientation = videoOrientation
        layer.connection?.videoOrientation = initialVideoOrientation
    }
}
