//
//  CameraAnimations.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/14/19.
//  Copyright © 2019 JNB. All rights reserved.
//
import UIKit
import Photos

extension MagnificationViewController {
  func detailLayout() {
    currentOrientation = .portrait
    topProButton.layer.cornerRadius = topProButton.frame.height/2
    previousUserImageView.layer.cornerRadius = previousUserImageView.frame.height/2
    flipButton.layer.cornerRadius = flipButton.frame.height/2
    flipButton.layer.borderColor = UIColor.white.cgColor
    flipButton.layer.borderWidth = 2.0
    previousUserImageView.layer.borderColor = UIColor.white.cgColor
    previousUserImageView.layer.borderWidth = 2.0
    previousUserImageView.isHidden = previousUserImageView.image == nil
    topProButton.layer.borderColor = UIColor.white.cgColor
    topProButton.layer.borderWidth = 2.0
    previewImageView.layer.shadowColor = UIColor.black.cgColor
    previewImageView.layer.shadowOffset = CGSize(width: 0, height: 0)
    previewImageView.layer.shadowOpacity = 0.55
    trackingView?.frame = CGRect(x: topProButton.center.x - 40, y: view.center.y - 120, width: 80, height: 80)
    rectOutline = trackingView?.frame
    imageViewSet: if album.auth == PHAuthorizationStatus.authorized  {
      guard album.assetCollection != nil else { break imageViewSet }
      guard let lastAsset = PHAsset.fetchAssets(in: album.assetCollection!, options: nil).lastObject else { return }
      fetchImage(asset: lastAsset) { (image) in
        self.previousUserImageView.image = image
      }
    }
  }
  
  @objc func orientationChanged() {
    currentOrientation = UIDevice.current.orientation
    var transform = CGAffineTransform.identity
    switch currentOrientation {
    case .portrait:
      break
    case .landscapeRight:
      transform = CGAffineTransform(rotationAngle: -.pi/2)
      break
    case .landscapeLeft:
      transform = CGAffineTransform(rotationAngle: .pi/2)
    default:
      break
    }
    UIView.animate(withDuration: 0.45) {
      self.previewImageView.transform = transform
      self.flipButton.transform = transform
      self.previewImageView.transform = transform
      self.topProButton.transform = transform
      self.previousUserImageView.transform = transform
    }
  }
  
  func animatePreviewCapture() {
    let animateImageView = UIImageView(frame: previewImageView.frame)
    animateImageView.image = previewImageView.image
    animateImageView.alpha = 0.6
    animateImageView.contentMode = UIView.ContentMode.scaleAspectFit
    animateImageView.layer.cornerRadius = previewImageView.frame.height/2
    animateImageView.clipsToBounds = true
    animateImageView.layer.borderColor = UIColor.white.cgColor
    animateImageView.layer.borderWidth = 2.0
    view.addSubview(animateImageView)
    view.bringSubviewToFront(animateImageView)
    
    UIView.animate(withDuration: 0.65, delay: 0, options: .curveEaseIn, animations: {
      animateImageView.layer.cornerRadius = self.previousUserImageView.frame.height/2
      animateImageView.frame = self.previousUserImageView.frame
    }) { (completed) in
      guard completed else { return }
      self.previousUserImageView.image = animateImageView.image
      animateImageView.removeFromSuperview()
      if self.previousUserImageView.image == nil {
        // do first time gallery thing
        self.viewImage()
      }
      if self.previousUserImageView.isHidden { self.previousUserImageView.isHidden = false }
    }
  }
}
