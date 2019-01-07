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
  var imageTouchOffset: CGPoint?
  var isFront = false 
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }
  override var shouldAutorotate: Bool { return false }
  override var prefersStatusBarHidden: Bool { return true }
  
  let deviceQueue = DispatchQueue(label: "moe.camera.device", autoreleaseFrequency: .workItem)
  let videoBufferQueue = DispatchQueue(label: "moe.camera.buffer", autoreleaseFrequency: .workItem)
  
  public var captureSession = AVCaptureSession()
  public var captureOutput = AVCaptureVideoDataOutput()
  public var photoOutput = AVCapturePhotoOutput()
  
  lazy var backDevice: AVCaptureDevice? = { return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices.first }()
  lazy var frontDevice: AVCaptureDevice? = { return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices.first }()
  lazy var input: AVCaptureInput? = {
    return createInput()
  }()
  
  var visionHandler: (VNRequest, Error?) -> Void = { request, error in
    guard let results = request.results?.first as? VNDetectedObjectObservation else { return }
    debugPrint("following tracked object at: ", results.boundingBox)
  }
  
  let album = CustomPhotoAlbum.sharedInstance
  
  var semaphore = DispatchSemaphore(value: 1)
  var userImageLock = false
  
  var rectOutline: CGRect?
  var sizeWidth = CGFloat(0)
  var sizeHeight = CGFloat(0)
  var frameSize: CGSize? = nil
  
  var previewLayer: AVCaptureVideoPreviewLayer?
  
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
  
  @IBAction func flipButtonPressed(_ sender: UIButton) {
    rectOutline = nil
    trackingView?.removeFromSuperview()
    previewImageView.image = nil
    captureSession.beginConfiguration()
    isFront.toggle()
    if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
      for input in inputs {
        captureSession.removeInput(input)
      }
    }
    guard let tempInput = input else { return }
    if captureSession.canAddInput(tempInput) {
      captureSession.addInput(tempInput)
    }
    
    captureSession.commitConfiguration()
  }
  
  @IBAction func imageViewPanned(_ sender: UIPanGestureRecognizer) {
    let location = sender.location(in: view)
    
    func adjust() {
      guard let offset = imageTouchOffset else { return }
      previewImageView.frame.origin = CGPoint(x: location.x-offset.x, y: location.y-offset.y)
      UIView.animate(withDuration: 0.15) {
        self.previewImageView.layoutIfNeeded()
        guard self.previewImageView.layer.shadowOpacity != 0.55 else { return }
        self.previewImageView.layer.shadowOpacity = 0.55
      }
    }
    
    func reset() {
      UIView.animate(withDuration: 0.35) {
        self.previewImageView.transform = CGAffineTransform.identity
        self.previewImageView.layer.shadowOpacity = 0
      }
    }
    
    switch sender.state {
    case .began:
      imageTouchOffset = sender.location(in: previewImageView)
      debugPrint(imageTouchOffset!.x, imageTouchOffset!.y)
      previewImageView.layer.shadowColor = UIColor.black.cgColor
      previewImageView.layer.shadowOffset = CGSize(width: 0, height: 0)
      previewImageView.layer.shadowOpacity = 0.85
      previewImageView.layer.shadowRadius = 5
      previewImageView.clipsToBounds = false
      adjust()
    case .changed:
      adjust()
    case .cancelled, .failed:
      reset()
    case .ended:
      previewImageView.layer.shadowOpacity = 0
      adjust()
    case .possible:
      break
    }
  }
  
  @IBAction func imageViewTapped(_ sender: Any) {
    userImageLock.toggle()
    guard userImageLock else { return }
    func writeImg() {
      guard let img =  previewImageView.image else { return }
      //UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
      album.save(image: img)
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
    case .changed:
      adjust()
    case .ended:
      rectOutline = tracker.frame
      
      /*
      try? device?.lockForConfiguration()
      defer { device?.unlockForConfiguration() }
      guard let frame = frameSize else { return }
      guard let metaRect = previewLayer?.metadataOutputRectConverted(fromLayerRect: rectOutline!) else { return }
      let outputRect = captureOutput.outputRectConverted(fromMetadataOutputRect: metaRect)
      let highlightedArea = outputRect.applying(CGAffineTransform(translationX: 0, y: -frame.height)).applying(CGAffineTransform(scaleX: 1, y: -1))
      let devicePoint = CGPoint(x: highlightedArea.midX, y: highlightedArea.midY)
      device?.focusPointOfInterest = devicePoint
      device?.exposurePointOfInterest = devicePoint
      */
    case .cancelled:
      reset()
    default:
      break
    }
  }
}

