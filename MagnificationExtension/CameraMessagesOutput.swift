//
//  CameraMessagesOutput.swift
//  MagnificationExtension
//
//  Created by John N Blanchard on 1/25/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import AVFoundation
import UIKit

extension MessagesViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    //print("output")
  }
  
  func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    print("drop")
  }
}
