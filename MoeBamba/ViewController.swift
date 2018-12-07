//
//  ViewController.swift
//  MoeBamba
//
//  Created by John N Blanchard on 12/7/18.
//  Copyright © 2018 JNB. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }
  override var shouldAutorotate: Bool { return false }
  
  let deviceQueue = DispatchQueue(label: "moe.camera.device", autoreleaseFrequency: .workItem)
  let videoBufferQueue = DispatchQueue(label: "moe.camera.buffer", autoreleaseFrequency: .workItem)
  
  public var captureSession = AVCaptureSession()
  public var captureOutput = AVCaptureVideoDataOutput()
  
  lazy var device: AVCaptureDevice? = { return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices.first }()
  lazy var input: AVCaptureInput? = {
    return createInput()
  }()
  
  var rectOutline: CGRect?
  var sizeWidth = CGFloat(0)
  var sizeHeight = CGFloat(0)
  
  var trackingView: TrackingView? {
    for aView in view.subviews {
      if aView is TrackingView {
        return aView as? TrackingView
      }
    }
    let temp = TrackingView(frame: CGRect.zero)
    temp.layer.borderColor = UIColor.green.cgColor
    temp.layer.borderWidth = 3.0
    view.addSubview(temp)
    return temp
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    sizeWidth = view.frame.width
    sizeHeight = view.frame.height
    let pangr = UIPanGestureRecognizer(target: self, action: #selector(handlePan(gr:)))
    view.addGestureRecognizer(pangr)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    start()
  }
  
  @objc func handlePan(gr: UIPanGestureRecognizer) {
    guard let tracker = trackingView else { return }
    
    func adjust() {
      let location = gr.location(in: view)
      var x = tracker.startingLocation.x
      var width = location.x - tracker.startingLocation.x
      if tracker.startingLocation.x > location.x {
        x = location.x
        width = tracker.startingLocation.x - location.x
      }
      var height = location.y - tracker.startingLocation.y
      var y = tracker.startingLocation.y
      if tracker.startingLocation.y > location.y {
        y = location.y
        height = tracker.startingLocation.y - location.y
      }
      tracker.frame = CGRect(x: x, y: y, width: width, height: height)
      UIView.animate(withDuration: 0.2) {
        self.view.layoutIfNeeded()
      }
    }
    
    func reset() {
      rectOutline = nil
      tracker.frame = CGRect.zero
      view.bringSubviewToFront(tracker)
      view.layoutIfNeeded()
    }
    switch gr.state {
    case .began:
      tracker.startingLocation = gr.location(in: view)
      reset()
    case .changed, .ended:
      adjust()
      rectOutline = tracker.frame
    case .cancelled:
      reset()
    default:
      break
    }
  }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
    guard rectOutline != nil else { return }
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let ciImg = CIImage(cvImageBuffer: buffer).oriented(forExifOrientation: 6)
    func adjustForCrop() -> CGRect {
      let xRatio = ciImg.extent.maxX / sizeWidth
      let yRatio = ciImg.extent.maxY / sizeHeight
      return CGRect(x: rectOutline!.minX*xRatio, y: rectOutline!.minY*yRatio, width: rectOutline!.width*xRatio, height: rectOutline!.height*yRatio)
    }
    //cropped to image -- need to check landscape
    let img = ciImg.cropped(to: adjustForCrop())
  }
  
  func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
  }
}

