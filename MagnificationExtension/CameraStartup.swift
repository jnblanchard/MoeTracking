//
//  CameraStartup.swift
//  MagnificationExtension
//
//  Created by John N Blanchard on 1/25/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import UIKit
import AVFoundation


extension MessagesViewController {
  func start() {
    func createOutput() {
      guard !captureSession.isRunning else { return }
      captureSession.beginConfiguration()
      if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
        for input in inputs {
          captureSession.removeInput(input)
        }
      }
      
      captureOutput.setSampleBufferDelegate(self, queue: videoBufferQueue)
      captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
      if captureSession.canAddOutput(captureOutput) {
        captureSession.addOutput(captureOutput)
      }
      
      photoOutput.isHighResolutionCaptureEnabled = true
      
      if captureSession.canAddOutput(photoOutput) {
        captureSession.addOutput(photoOutput)
      }
      
      let settings = AVCapturePhotoSettings()
      settings.isHighResolutionPhotoEnabled = true
      photoOutput.setPreparedPhotoSettingsArray([settings], completionHandler: nil)
      captureSession.sessionPreset = .photo
      
      guard let tempInput = createInput() else { return }
      if captureSession.canAddInput(tempInput) {
        captureSession.addInput(tempInput)
      }
      
      captureSession.commitConfiguration()
      
      captureOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
      
      previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
      previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
      previewLayer?.connection?.videoOrientation = .portrait
      DispatchQueue.main.async {
        
        self.view.layer.addSublayer(self.previewLayer!)
        let temp_layer = self.view.layer
        self.previewLayer?.frame = temp_layer.bounds
        self.view.layoutIfNeeded()
        
        for temp in self.view.subviews {
          //if temp == self.backgroundMagImage { continue }
          self.view.bringSubviewToFront(temp) }
      }
      
      guard !captureSession.isRunning else { return }
      deviceQueue.async { self.captureSession.startRunning() }
    }
    
    func noCameraSettingsScreen() {
      DispatchQueue.main.async {
        self.performSegue(withIdentifier: "noCamera", sender: self)
      }
    }
    
    switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
    case .authorized:
      createOutput()
    case .denied:
      noCameraSettingsScreen()
      // set auth
    //ask for settings auth TODO
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
        guard response else {
          noCameraSettingsScreen()
          return
        }
        createOutput()
      }
    case .restricted:
      // Continue with restriction
      noCameraSettingsScreen()
    }
  }
  
  func createInput() -> AVCaptureDeviceInput? {
    var device: AVCaptureDevice? = isFront ? frontDevice : backDevice
    var bestFormat: AVCaptureDevice.Format?
    var bestFrameRateRange: AVFrameRateRange?
    for format in device!.formats {
      for range in format.videoSupportedFrameRateRanges {
        guard bestFrameRateRange != nil else {
          bestFormat = format
          bestFrameRateRange = range
          continue
        }
        guard Double(bestFrameRateRange!.maxFrameRate) < Double((range as AnyObject).maxFrameRate) else { continue }
        bestFormat = format
        bestFrameRateRange = range
      }
    }
    do {
      try device?.lockForConfiguration()
      defer { device?.unlockForConfiguration() }
      device?.activeFormat = bestFormat!
      device?.activeVideoMinFrameDuration = bestFrameRateRange?.minFrameDuration ?? CMTime.zero
      device?.activeVideoMaxFrameDuration = bestFrameRateRange?.maxFrameDuration ?? CMTime.zero
      
      if device!.isTorchAvailable { device?.torchMode = .off }
      
      if device!.isFocusModeSupported(.continuousAutoFocus) {
        device!.focusMode = .continuousAutoFocus
      } else if device!.isFocusModeSupported(.autoFocus) {
        device!.focusMode = .autoFocus
      }
      if device!.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
        device!.whiteBalanceMode = .continuousAutoWhiteBalance
      } else if device!.isWhiteBalanceModeSupported(.autoWhiteBalance) {
        device!.whiteBalanceMode = .autoWhiteBalance
      }
      if device!.isExposureModeSupported(.continuousAutoExposure) {
        device!.exposureMode = .continuousAutoExposure
        
      } else if device!.isExposureModeSupported(.autoExpose) {
        device!.exposureMode = .autoExpose
      }
    } catch {
      debugPrint("error in \(#function): \(error)")
    }
    return try? AVCaptureDeviceInput(device:  device!)
  }
}

extension UIViewController {
  var trackingView: TrackingView? {
    for aView in view.subviews {
      if aView is TrackingView {
        return aView as? TrackingView
      }
    }
    let temp = TrackingView(frame: CGRect.zero)
    temp.layer.borderColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.6).cgColor
    temp.layer.borderWidth = 3.0
    view.addSubview(temp)
    return temp
  }
}
