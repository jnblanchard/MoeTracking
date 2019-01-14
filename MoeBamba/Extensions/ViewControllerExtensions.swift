//
//  ViewControllerExtensions.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/13/19.
//  Copyright © 2019 JNB. All rights reserved.
//
import UIKit

extension UINavigationController {
  override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return topViewController?.supportedInterfaceOrientations ?? .portrait
  }
}

extension UIViewController {
  func forcePortrait() {
    UIView.setAnimationsEnabled(false)
    UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    UIView.setAnimationsEnabled(true)
    guard let mag = self as? MagnificationViewController else { return }
    mag.sizeWidth = view.frame.width
    mag.sizeHeight = view.frame.height
  }
}
