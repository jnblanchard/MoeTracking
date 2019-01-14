//
//  ViewImageViewController.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/11/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import UIKit
import Photos

class ViewImageViewController: UIViewController {
  
  @IBOutlet weak var warningBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageScrollView: ImageScrollView!
  
  @IBOutlet weak var bottomWarningView: UIView!
  
  var image: UIImage?
  var saved: Bool = true
  
  var didFinishDisplay: Bool = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if let img = image, !didFinishDisplay {
      imageScrollView.display(image: img)
      imageScrollView.adjustFrameToCenter()
      view.layoutIfNeeded()
      didFinishDisplay = true
    }
    guard PHPhotoLibrary.authorizationStatus() != .authorized else {
      guard !saved, let img = image else { return }
      CustomPhotoAlbum.sharedInstance.save(image: img)
      return
    }
    warningBottomConstraint.constant = 25
    UIView.animate(withDuration: 0.95, delay: 0, options: .curveEaseIn, animations: {
      self.view.layoutIfNeeded()
    }, completion: nil)
  }
  
  @IBAction func okaySettingsButtonTapped(_ sender: Any) {
    warningBottomConstraint.constant = -600
    UIView.animate(withDuration: 0.95, delay: 0, options: .curveEaseIn, animations: {
      self.view.layoutIfNeeded()
    }, completion: nil)
  }
  
  @IBAction func settingsButtonPressed(_ sender: Any) {
    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
  }
  
  @IBAction func backButtonTapped(_ sender: Any) {
    dismiss(animated: true, completion: nil)
  }
  
  deinit {
    image = nil
  }
}
