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
    let crop = ci.cropped(to: outputRect).oriented(forExifOrientation: 6)
    guard let cgCrop = CIContext(options: nil).createCGImage(crop, from: crop.extent) else { return }
    let cropUI = UIImage(cgImage: cgCrop)
    album.save(image: cropUI)
    previewImageView.image = cropUI
  }
}
