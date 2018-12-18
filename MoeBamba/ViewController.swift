//
//  ViewController.swift
//  MoeBamba
//
//  Created by John N Blanchard on 12/7/18.
//  Copyright © 2018 JNB. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
  @IBOutlet weak var previewImageView: UIImageView!
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }
  override var shouldAutorotate: Bool { return false }
  override var prefersStatusBarHidden: Bool { return true }
  
  let deviceQueue = DispatchQueue(label: "moe.camera.device", autoreleaseFrequency: .workItem)
  let videoBufferQueue = DispatchQueue(label: "moe.camera.buffer", autoreleaseFrequency: .workItem)
  
  public var captureSession = AVCaptureSession()
  public var captureOutput = AVCaptureVideoDataOutput()
  public var photoOutput = AVCapturePhotoOutput()
  
  lazy var device: AVCaptureDevice? = { return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices.first }()
  lazy var input: AVCaptureInput? = {
    return createInput()
  }()
  
  var visionHandler: (VNRequest, Error?) -> Void = { request, error in
    debugPrint(request.results)
  }
  
  var semaphore = DispatchSemaphore(value: 1)
  var userImageLock = false
  
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
  
  @IBAction func imageViewTapped(_ sender: Any) {
    userImageLock.toggle()
    debugPrint(userImageLock)
    guard userImageLock else { return }
    func writeImg() {
      guard let img =  previewImageView.image else { return }
      UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
    }
    
    func takeImg() {
      let settings = AVCapturePhotoSettings()
      settings.isHighResolutionPhotoEnabled = true
      photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    takeImg()
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
      UIView.animate(withDuration: 0.1) {
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

extension ViewController: AVCapturePhotoCaptureDelegate {
  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    guard let img = photo.cgImageRepresentation()?.takeRetainedValue() else { return }
    let ci = CIImage(cgImage: img)
    guard let uiRect = rectOutline else { return }
    let xRatio = CGFloat(img.width) / sizeWidth
    let yRatio = CGFloat(img.height) / sizeHeight
    
    let bigRect = CGRect(x: uiRect.origin.x*xRatio, y: uiRect.origin.y*yRatio, width: uiRect.width*xRatio, height: uiRect.height*yRatio)
    let crop = ci.cropped(to: bigRect)
    
    debugPrint(img.height, img.width, crop.extent.width, crop.extent.height)
  }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    semaphore.wait()
    defer { semaphore.signal() }
    guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
    guard rectOutline != nil else { return }
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let ciImg = CIImage(cvImageBuffer: buffer).oriented(forExifOrientation: 6)
    func adjustForCrop() -> CGRect {
      let xRatio = CGFloat(ciImg.extent.width / sizeWidth)
      let yRatio = CGFloat(ciImg.extent.height / sizeHeight)
      
      /*
       dxx = 5*3 (300 / 100) dxy = 50*2.5 (500/200)
       width1 = 300 height1 = 500
       dx1 = 5, dy1 = 50
       width2 = 100 height2 = 200
       
      */
      let rect1 = rectOutline!.applying(CGAffineTransform(scaleX: xRatio, y: yRatio))
      
      let rect = CGRect(x: rectOutline!.origin.x*xRatio, y:  (rectOutline!.origin.y*yRatio), width: rectOutline!.size.width*xRatio, height: rectOutline!.size.height*yRatio).applying(CGAffineTransform.init(scaleX: 1, y: -1))
      return rect1
    }
    //cropped to image -- need to check landscape
    let highlightedArea = adjustForCrop()
    let img = ciImg.cropped(to: highlightedArea)
    DispatchQueue.main.async {
      guard !self.userImageLock else { return }
      guard let cgimg = CIContext(options: nil).createCGImage(img, from: img.extent) else { return }
      self.previewImageView.image = UIImage(cgImage: cgimg)
    }
    let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
    let request = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: highlightedArea), completionHandler: visionHandler)
    do {
      try handler.perform([request])
    } catch {
      debugPrint(error)
    }
  }
  
  func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
  }
}

