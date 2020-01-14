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
import Photos
//import StoreKit

class MagnificationViewController: UIViewController {
  @IBOutlet weak var backgroundMagImage: UIImageView!
  @IBOutlet weak var flipButton: UIButton!
  @IBOutlet weak var topProButton: UIButton!
  @IBOutlet weak var previousUserImageView: UIImageView!
  @IBOutlet weak var previewImageView: UIImageView!
  var userImageLock = false {
    didSet {
      if userImageLock {
        let _ = createPreviewCoverView(with: "Tap to unlock.", defaultSize: 110)
        let _ = createViewImageButton()
      } else {
        if let viewImageButton = previewImageView.subviews.first(where: { (aView) -> Bool in
          return aView is UIButton
        }) {
          viewImageButton.removeFromSuperview()
        }
        
        if let firstTimeCoverView = previewImageView.subviews.first(where: { (aView) -> Bool in
          guard let temp = aView as? UILabel else { return false }
          return temp.text == "Tap to unlock."
        }) {
          firstTimeCoverView.removeFromSuperview()
        }
      }
    }
  }
  var imageTouchOffset: CGPoint?
  var isFront = false
  var writeOverTen = false //is able to store > 300
  
  var testLayovers = false //forces first time layover experience
  
  var currentOrientation: UIDeviceOrientation = .portrait
  
  override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {return .portrait }
  override open var shouldAutorotate: Bool { return false }
  override open var prefersStatusBarHidden: Bool { return true }
  
  let deviceQueue = DispatchQueue(label: "moe.camera.device", autoreleaseFrequency: .workItem)
  let videoBufferQueue = DispatchQueue(label: "moe.camera.buffer", autoreleaseFrequency: .workItem)
  
  public var captureSession = AVCaptureSession()
  public var captureOutput = AVCaptureVideoDataOutput()
  public var photoOutput = AVCapturePhotoOutput()
  
  lazy var backDevice: AVCaptureDevice? = { return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices.first }()
  lazy var frontDevice: AVCaptureDevice? = { return AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices.first }()
  
  let album = CustomPhotoAlbum.sharedInstance
  //let subscriptionManager = SubscriptionManager.shared
  
  var semaphore = DispatchSemaphore(value: 1)
  
  var zoomFactor: CGFloat = 1.0
  var rectOutline: CGRect?
  var sizeWidth = CGFloat(0)
  var sizeHeight = CGFloat(0)
  var frameSize: CGSize? = nil
  
  var previewLayer: AVCaptureVideoPreviewLayer?
  /*
  var visionHandler: (VNRequest, Error?) -> Void = { request, error in
    guard let results = request.results?.first as? VNDetectedObjectObservation else { return }
    debugPrint("following tracked object at: ", results.boundingBox)
  }
  */
  
  override func viewDidLoad() {
    super.viewDidLoad()
    forcePortrait()
    NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
    //SKPaymentQueue.default().add(self)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    detailLayout()
    start()
  }
  
  @IBAction func focusTap(_ tap: UITapGestureRecognizer) {
    let focusPoint =  tap.location(in: view)
    guard let captureDeviceLocation = previewLayer?.captureDevicePointConverted(fromLayerPoint: focusPoint) else { return }
    guard let device = isFront ? frontDevice : backDevice else { return }
    guard device.isFocusPointOfInterestSupported, device.isExposurePointOfInterestSupported else { return }
    
    do {
      try device.lockForConfiguration()
      
      device.focusPointOfInterest = captureDeviceLocation
      device.exposurePointOfInterest = captureDeviceLocation
      
      device.focusMode = .continuousAutoFocus
      device.exposureMode = .continuousAutoExposure
      
      device.unlockForConfiguration()
    } catch {
      print(error)
    }
  }
  
  @IBAction func pinchToZoomObserved(_ pinch: UIPinchGestureRecognizer) {
    guard let device = isFront ? frontDevice : backDevice else { return }
    func minMaxZoom(_ factor: CGFloat) -> CGFloat { return min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor) }
    
    func update(scale factor: CGFloat) {
      do {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        device.videoZoomFactor = factor
      } catch {
        debugPrint(error)
      }
    }
    
    let newScaleFactor = minMaxZoom(pinch.scale * zoomFactor)
    
    switch pinch.state {
    case .began: fallthrough
    case .changed: update(scale: newScaleFactor)
    case .ended:
      zoomFactor = minMaxZoom(newScaleFactor)
      update(scale: zoomFactor)
    default: break
    }
  }
  
  @IBAction func flipButtonPressed(_ sender: UIButton) {
    rectOutline = nil
    trackingView?.removeFromSuperview()
    previewImageView.image = nil
    isFront.toggle()
    captureSession.beginConfiguration()
    if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
      for input in inputs {
        captureSession.removeInput(input)
      }
    }
    guard let tempInput = createInput() else { return }
    if captureSession.canAddInput(tempInput) {
      captureSession.addInput(tempInput)
    }
    
    captureOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
    
    captureSession.commitConfiguration()
    
    trackingView?.frame = CGRect(x: topProButton.center.x - 40, y: view.center.y - 120, width: 80, height: 80)
    rectOutline = trackingView?.frame
    userImageLock = false
  }
  
  @IBAction func imageViewPanned(_ sender: UIPanGestureRecognizer) {
    let location = sender.location(in: view)
    
    func adjust() {
      guard let offset = imageTouchOffset else { return }
      previewImageView.frame.origin = CGPoint(x: location.x-offset.x, y: location.y-offset.y)
      UIView.animate(withDuration: 0.15) {
        self.previewImageView.layoutIfNeeded()
        guard self.previewImageView.layer.shadowOpacity != 0.55 else { return }
        self.previewImageView.layer.shadowOpacity = 0.90
      }
    }
    
    func reset() {
      UIView.animate(withDuration: 0.35) {
        self.previewImageView.transform = CGAffineTransform.identity
        self.previewImageView.layer.shadowOpacity = 0.55
      }
    }
    
    switch sender.state {
    case .began:
      imageTouchOffset = sender.location(in: previewImageView)
      previewImageView.layer.shadowOpacity = 0.85
      previewImageView.layer.shadowRadius = 5
      previewImageView.clipsToBounds = false
      adjust()
    case .changed:
      adjust()
    case .cancelled, .failed:
      reset()
    case .ended:
      previewImageView.layer.shadowOpacity = 0.55
      adjust()
    case .possible:
      break
    @unknown default:
      break
    }
  }
  
  @IBAction func imageViewTapped(_ sender: Any) {
    removeCaptureLayover()
    userImageLock.toggle()
    guard userImageLock else { return }
    
    guard album.count() < 300 || writeOverTen else {
      album.removeEldest()
      return
    }
    
    animatePreviewCapture()
    
    // from buffer; faster, but smaller
    func writeImg() {
      guard let img =  previewImageView.image else { return }
      //UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
      previewImageView.image = img
      album.save(image: img)
    }
    
    // photoOutput; slower, bigger 12mp
    func takeImg() {
      let settings = AVCapturePhotoSettings()
      settings.isHighResolutionPhotoEnabled = true
      photoOutput.capturePhoto(with: settings, delegate: self)
    }

    takeImg()
  }
  
  @IBAction func handleTrackerViewPan(_ sender: UIPanGestureRecognizer) {
    guard let tracker = trackingView else { return }
    
    func adjust() {
      let location = sender.location(in: view)
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
      UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut, animations: {
        self.previewImageView.layoutIfNeeded()
      }) { (completed) in
        guard completed else { return }
      }
    }
    switch sender.state {
    case .began:
      reset()
      tracker.startingLocation = sender.location(in: view)
      guard userImageLock else { return }
      userImageLock = false
    case .changed:
      adjust()
    case .ended:
      rectOutline = tracker.frame
      view.insertSubview(tracker, at: 2)
    case .cancelled:
      reset()
    default:
      break
    }
  }
  
  @IBAction func previousImageTapped(_ sender: UITapGestureRecognizer) { UIApplication.shared.open(URL(string:"photos-redirect://")!) }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let viewImageVC = segue.destination as? ViewImageViewController {
      viewImageVC.image = previewImageView.image
      viewImageVC.saved = PHPhotoLibrary.authorizationStatus() == .authorized
    }
    
//    if let proOfferVC = segue.destination as? ProOfferViewController {
//      proOfferVC.product = subscriptionManager.products.last
//      proOfferVC.album = album
//    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
//    SKPaymentQueue.default().remove(self)
  }
}

