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
      
      captureSession.sessionPreset = .high
      captureOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
      
      guard let tempInput = input else { return }
      if captureSession.canAddInput(tempInput) {
        captureSession.addInput(tempInput)
      }
      
      captureSession.commitConfiguration()
      
      let tempLayer = AVCaptureVideoPreviewLayer(session: captureSession)
      tempLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
      tempLayer.frame = view.bounds
      view.layer.addSublayer(tempLayer)
      for temp in view.subviews { view.bringSubviewToFront(temp) }
      
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
      //ask for settings auth
      break
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
        if response {
          createOutput()
        } else {
//          debugPrint("rejection")
        }
      }
    case .restricted:
      // Continue with restriction
      break
    }
  }
  
  func createInput() -> AVCaptureDeviceInput? {
    guard device != nil else { return nil }
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
