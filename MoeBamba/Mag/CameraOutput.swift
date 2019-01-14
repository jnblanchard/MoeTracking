//
//  CameraOutput.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/7/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit


extension MagnificationViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    semaphore.wait()
    defer { semaphore.signal() }
    guard previewLayer != nil else { return }
    guard rectOutline != nil else { return }
    guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let wrongOrientationImage = CIImage(cvImageBuffer: buffer)
    var ciImg = wrongOrientationImage  //.oriented(forExifOrientation: 6)
    if frameSize != wrongOrientationImage.extent.size {
      frameSize = wrongOrientationImage.extent.size
    }
    func adjustForCrop() -> CGRect? {
      guard rectOutline != nil else { return nil }
      guard let metaRect = previewLayer?.metadataOutputRectConverted(fromLayerRect: rectOutline!) else { return nil }
      return output.outputRectConverted(fromMetadataOutputRect: metaRect)
    }
    //cropped to image -- need to check landscape
    guard let highlightedArea = adjustForCrop()?.applying(CGAffineTransform(translationX: 0, y: -ciImg.extent.height)).applying(CGAffineTransform(scaleX: 1, y: -1)) else { return }
    let img = ciImg.cropped(to: highlightedArea)
    var relativeImg = img
    switch currentOrientation {
    case .portrait:
      break
    case .landscapeRight:
      relativeImg = img.oriented(forExifOrientation: 6)
    case .landscapeLeft:
      relativeImg = img.oriented(forExifOrientation: 8)
    default:
      break
    }
    DispatchQueue.main.async {
      guard !self.userImageLock else { return }
      guard let cgimg = CIContext(options: nil).createCGImage(relativeImg, from: relativeImg.extent) else { return }
      self.previewImageView.image = UIImage(cgImage: cgimg)
    }
    /*
     let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
     let request = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: highlightedArea), completionHandler: visionHandler)
     do {
     try handler.perform([request])
     } catch {
     debugPrint(error)
     }
     */
  }
  
  func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
  }
}
