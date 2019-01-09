//
//  CameraSetup.swift
//  MoeBamba
//
//  Created by John N Blanchard on 12/7/18.
//  Copyright © 2018 JNB. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

extension ViewController {
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
        self.previewLayer?.frame = self.view.bounds
        self.view.layer.addSublayer(self.previewLayer!)
        for temp in self.view.subviews { self.view.bringSubviewToFront(temp) }
      }
      
      guard !captureSession.isRunning else { return }
      deviceQueue.async { self.captureSession.startRunning() }
    }
    
    UIView.setAnimationsEnabled(false)
    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    UIView.setAnimationsEnabled(true)
    switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
    case .authorized:
      createOutput()
      break
    case .denied:
      //ask for settings auth TODO
      break
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
        guard response else { return }
        createOutput()
      }
    case .restricted:
      // Continue with restriction
      break
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
