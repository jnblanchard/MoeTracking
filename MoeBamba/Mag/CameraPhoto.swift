//
//  CameraPhoto.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/7/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import Photos

extension ViewController: AVCapturePhotoCaptureDelegate {
  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    guard let img = photo.cgImageRepresentation()?.takeUnretainedValue() else { return }
    let ci = CIImage(cgImage: img)
    guard let uiRect = rectOutline else { return }
    guard let metaRect = previewLayer?.metadataOutputRectConverted(fromLayerRect: uiRect) else { return }
    let outputRect = output.outputRectConverted(fromMetadataOutputRect: metaRect).applying(CGAffineTransform(translationX: 0, y: -ci.extent.height)).applying(CGAffineTransform(scaleX: 1, y: -1))
    var crop = ci.cropped(to: outputRect)
    switch currentOrientation {
    case .portrait:
      crop = crop.oriented(forExifOrientation: 6)
    case .landscapeRight:
      crop = crop.oriented(forExifOrientation: 3)
    case .landscapeLeft:
      crop = crop.oriented(forExifOrientation: 1)
    default:
      break
    }
    guard let cgCrop = CIContext(options: nil).createCGImage(crop, from: crop.extent) else { return }
    let cropUI = UIImage(cgImage: cgCrop)
    album.save(image: cropUI)
    previousUserImageView.image = cropUI
    previewImageView.image = cropUI
    /*
    switch currentOrientation {
    case .portrait:
      guard let cgCrop = CIContext(options: nil).createCGImage(crop, from: crop.extent) else { return }
      let cropUI = UIImage(cgImage: cgCrop)
      album.save(image: cropUI)
      previousUserImageView.image = cropUI
      previewImageView.image = cropUI
    case .landscapeLeft:
      crop =  ci.cropped(to: outputRect).oriented(forExifOrientation: 0)
      guard let cgCrop = CIContext(options: nil).createCGImage(crop, from: crop.extent) else { return }
      let cropUI = UIImage(cgImage: cgCrop)
      album.save(image: cropUI)
      previousUserImageView.image = cropUI
      previewImageView.image = cropUI
    case .landscapeRight:
//      crop = ci.cropped(to: outputRect).oriented(forExifOrientation: 3)
//      guard let cgCrop = CIContext(options: nil).createCGImage(crop, from: crop.extent) else { return }
//      let cropUI = UIImage(cgImage: cgCrop)
      let cropRelative = ci.cropped(to: outputRect).oriented(forExifOrientation: 6)
      guard let cgCropRelative = CIContext(options: nil).createCGImage(cropRelative, from: cropRelative.extent) else { return }
      let cropRelativeUI = UIImage(cgImage: cgCropRelative)
      previousUserImageView.image = cropRelativeUI
      previewImageView.image = cropRelativeUI
      album.save(image: cropRelativeUI)
    default:
      break
    }
    */
  }
}
