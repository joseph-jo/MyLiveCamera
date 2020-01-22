//
//  AVStreamManager.swift
//  MyLiveCamera
//
//  Created by Joseph Chen on 2020/1/21.
//  Copyright © 2020 Joseph Chen. All rights reserved.
//

import UIKit
import AVFoundation


enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}

class AVStreamManager: NSObject {
    
    static let manager = AVStreamManager()
        
    var setupResult: SessionSetupResult = .success
    let sessionQueue = DispatchQueue(label: "sessionQueue")
    var sessionCapture: AVCaptureSession!
    
    var defaultCameraDevice: AVCaptureDevice!
    var videoDeviceInput: AVCaptureDeviceInput!
    var audioDeviceInput: AVCaptureDeviceInput!
    
    override init() {
        super.init()
        self.registerNotifications()
        
        self.sessionCapture = AVCaptureSession()
    }
        
    func startRunning(completionHandler: @escaping (SessionSetupResult) -> ()) {
        
        // 1.
        self.requireAuthorization()
        if setupResult == .notAuthorized {
            completionHandler(setupResult)
            return
        }
        
        sessionQueue.async {
            
            // 2.
            self.configureSession()
            if self.setupResult != .success {
                DispatchQueue.main.async {
                    completionHandler(self.setupResult)
                }
                return
            }
            
            // 3.
            self.sessionCapture.startRunning()
            DispatchQueue.main.async {
                completionHandler(self.setupResult)
            }
        }
    }
}
extension AVStreamManager {
    
    func requireAuthorization() {

        /*
         Check the video authorization status. Video access is required and audio
         access is optional. If the user denies audio access, AVCam won't
         record audio during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
    }
}

extension AVStreamManager {
    
    /*
     Setup the capture session.
     In general, it's not safe to mutate an AVCaptureSession or any of its
     inputs, outputs, or connections from multiple threads at the same time.
     
     Don't perform these tasks on the main queue because
     AVCaptureSession.startRunning() is a blocking call, which can
     take a long time. Dispatch session setup to the sessionQueue, so
     that the main queue isn't blocked, which keeps the UI responsive.
     */
    func configureSession() {
        
        sessionCapture.beginConfiguration()
        sessionCapture.sessionPreset = .medium
        
        guard let videoDevice = self.getCameraDevice(position: .back),
            let audioDevice = AVCaptureDevice.default(for: .audio) else {
                sessionCapture.commitConfiguration()
                return
        }
        
        self.setupAVInput(videoDevice: videoDevice, audioDevice: audioDevice)
        sessionCapture.commitConfiguration()
    }
    
    func getCameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
         
        switch position {
        case .back:
            if let newCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                return newCameraDevice
            }
            else if let newCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                return newCameraDevice
            }
        case .front:
            if let newCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                return newCameraDevice
            }
        default:
            return nil
        }
        return nil
    }
    
    func setupAVInput(videoDevice: AVCaptureDevice, audioDevice: AVCaptureDevice) {
        
        // Video
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if sessionCapture.canAddInput(videoDeviceInput) {
                sessionCapture.addInput(videoDeviceInput)
            }
            else {
                NSLog("Couldn't add video device input to the session. \(videoDeviceInput)")
                self.setupResult = .configurationFailed
                return
            }
            self.videoDeviceInput = videoDeviceInput
        }
        catch {
            NSLog("Couldn't create video device input: \(error)")
            self.setupResult = .configurationFailed
            return
        }
        
        // Audio
        do {
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if sessionCapture.canAddInput(audioDeviceInput) {
                sessionCapture.addInput(audioDeviceInput)
            }
            else {
                NSLog("Could not add audio device input to the session\(audioDeviceInput)")
                self.setupResult = .configurationFailed
                return
            }
            self.audioDeviceInput = audioDeviceInput
        }
        catch {
            NSLog("Could not create audio device input: \(error)")
            self.setupResult = .configurationFailed
            return
        }

        self.setupResult = .success
    }
}
