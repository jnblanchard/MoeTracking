//
//  LayoverExperience.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/9/19.
//  Copyright © 2019 JNB. All rights reserved.
//
import UIKit
import StoreKit

extension MagnificationViewController {
  
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
  
  func showNoCameraCover() {
    
  }
  
  @objc func viewImage() {
    DispatchQueue.main.async { self.performSegue(withIdentifier: "viewImage", sender: self) }
  }
  
  func createViewImageButton() -> UIButton {
    let coverButton = UIButton(frame: previewImageView.frame)
    coverButton.clipsToBounds = true
    coverButton.backgroundColor = UIColor(white: 0, alpha: 0.4)
    coverButton.setAttributedTitle(NSAttributedString(string: "Tap to View", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 19, weight: .bold), NSAttributedString.Key.foregroundColor: UIColor.white]), for: .normal)
    coverButton.translatesAutoresizingMaskIntoConstraints = false
    coverButton.layer.cornerRadius = 6
    coverButton.layer.borderColor = UIColor.white.cgColor
    coverButton.layer.borderWidth = 2.0
    coverButton.addTarget(self, action: #selector(viewImage), for: .touchUpInside)
    previewImageView.addSubview(coverButton)
    coverButton.centerXAnchor.constraint(equalTo: previewImageView.centerXAnchor).isActive = true
    coverButton.bottomAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: -7).isActive = true
    coverButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
    coverButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    return coverButton
  }
  
  func createPreviewCoverView(with text: String, defaultSize: CGFloat) -> UILabel {
    let coverView = UILabel(frame: previewImageView.frame)
    coverView.text = text
    coverView.numberOfLines = 2
    coverView.textColor = UIColor.white
    coverView.textAlignment = .center
    coverView.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
    coverView.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.5)
    coverView.translatesAutoresizingMaskIntoConstraints = false
    coverView.clipsToBounds = true
    coverView.layer.cornerRadius = defaultSize/2
    coverView.layer.borderColor = UIColor.white.cgColor
    coverView.layer.borderWidth = 2.0
    previewImageView.addSubview(coverView)
    coverView.centerXAnchor.constraint(equalTo: previewImageView.centerXAnchor).isActive = true
    coverView.centerYAnchor.constraint(equalTo: previewImageView.centerYAnchor).isActive = true
    coverView.widthAnchor.constraint(equalToConstant: defaultSize).isActive = true
    coverView.heightAnchor.constraint(equalToConstant: defaultSize).isActive = true
    return coverView
  }
  
  func setFirstTimeLayovers() {
    let _ = createPreviewCoverView(with: "Tap to capture.", defaultSize: 110)
  }
  
  func removeCaptureLayover() {
    guard let cover = previewImageView.subviews.first(where: { (aView) -> Bool in
      guard let temp = aView as? UILabel else { return false }
      return temp.text == "Tap to capture."
    }) else { return }
    cover.removeFromSuperview()
  }
  
  func requestReviewFor(attempt multiple: Int) {
    let launches = UserDefaults.standard.integer(forKey: "launches")
    guard launches > 1 && !testLayovers else {
      guard launches == 1 || testLayovers else { return }
      setFirstTimeLayovers()
      return
    }
    guard launches % multiple == 0 else { return }
    SKStoreReviewController.requestReview()
  }
}
