//
//  RectangleExtensions.swift
//  MoeBamba
//
//  Created by John N Blanchard on 12/17/18.
//  Copyright © 2018 JNB. All rights reserved.
//

import Foundation
import UIKit

extension CGRect {
  func scaleLinear(amount: Double) -> CGRect {
    guard amount != 1.0, amount > 0.0 else { return self }
    let ratio = CGFloat((1.0 - amount) / 2.0)
    return insetBy(dx: width * ratio, dy: height * ratio)
  }
  
  func scaleArea(amount: Double) -> CGRect {
    return scaleLinear(percent: sqrt(amount))
  }
  
  func scaleLinear(percent: Double) -> CGRect {
    return scaleLinear(amount: percent / 100)
  }
  
  func scaleArea(percent: Double) -> CGRect {
    return scaleArea(amount: percent / 100)
  }
}
