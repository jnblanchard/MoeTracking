//
//  NoCameraAuthViewController.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/11/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import UIKit

class NoCameraAuthViewController: UIViewController {
  
  @IBOutlet weak var settingsButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    settingsButton.layer.masksToBounds = false
    settingsButton.layer.shadowColor = UIColor.black.cgColor
    settingsButton.layer.shadowOffset = CGSize(width: 0, height: 0)
    settingsButton.layer.shadowOpacity = 0.85
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }
  
  @IBAction func settingsButtonTapped(_ sender: Any) {
    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
  }
  
}
