//
//  OutlineSetters.swift
//  MagnificationExtension
//
//  Created by John N Blanchard on 1/25/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import Foundation
import UIKit
import Messages

extension MessagesViewController {
  func setTrackingView(for state: MSMessagesAppPresentationStyle) {
    
    var rect: CGRect = CGRect(x: view.center.x-40, y: view.center.y-40, width: 80, height: 80)
    
    switch state {
    case .compact:
      break;
    case .expanded:
      break;
    case .transcript:
      break;
    }
    
    trackingView?.frame = rect
    rectOutline = trackingView?.frame
    trackingView?.layoutIfNeeded()
  }
}
