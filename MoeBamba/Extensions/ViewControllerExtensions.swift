//
//  ViewControllerExtensions.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/13/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
  func forcePortrait() {
    UIView.setAnimationsEnabled(false)
    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    UIView.setAnimationsEnabled(true)
  }
}
