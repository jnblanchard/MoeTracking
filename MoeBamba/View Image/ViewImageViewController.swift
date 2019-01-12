//
//  ViewImageViewController.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/11/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import UIKit

class ViewImageViewController: UIViewController {
  
  @IBOutlet weak var imageScrollView: ImageScrollView!
  
  var image: UIImage?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    if let img = image {
      imageScrollView.display(image: img)
    }
    guard CustomPhotoAlbum.sharedInstance.auth != .authorized else { return }
    
  }
  
  @IBAction func backButtonTapped(_ sender: Any) {
    navigationController?.dismiss(animated: true, completion: {
      self.image = nil
    })
  }
}
