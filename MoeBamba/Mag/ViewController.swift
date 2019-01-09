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
import StoreKit


class ViewController: UIViewController {
  @IBOutlet weak var flipButton: UIButton!
  @IBOutlet weak var topProButton: UIButton!
  @IBOutlet weak var previousUserImageView: UIImageView!
  @IBOutlet weak var previewImageView: UIImageView!
  var imageTouchOffset: CGPoint?
  var isFront = false
  var writeOverTen = false
  
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
   var zoomFactor: CGFloat = 1.0
  
  var visionHandler: (VNRequest, Error?) -> Void = { request, error in
    guard let results = request.results?.first as? VNDetectedObjectObservation else { return }
    debugPrint("following tracked object at: ", results.boundingBox)
  }
  
  let album = CustomPhotoAlbum.sharedInstance
  let subscriptionManager = SubscriptionManager.shared
  
  var semaphore = DispatchSemaphore(value: 1)
  var userImageLock = false {
    didSet {
      if userImageLock {
        let coverView = UILabel(frame: previewImageView.frame)
        coverView.text = "Tap to unlock."
        coverView.numberOfLines = 2
        coverView.textColor = UIColor.white
        coverView.textAlignment = .center
        coverView.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
        coverView.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.5)
        coverView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coverView)
        coverView.leadingAnchor.constraint(equalTo: previewImageView.leadingAnchor).isActive = true
        coverView.topAnchor.constraint(equalTo: previewImageView.topAnchor).isActive = true
        coverView.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor).isActive = true
        coverView.bottomAnchor.constraint(equalTo: previewImageView.bottomAnchor).isActive = true
      } else {
        guard let coverView = view.subviews.first(where: { (aView) -> Bool in
          guard let temp = aView as? UILabel else { return false }
          return temp.text == "Tap to unlock."
        }) else { return }
        coverView.removeFromSuperview()
      }
    }
  }
  
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
    temp.layer.borderColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.6).cgColor
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
    SKPaymentQueue.default().add(self)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    topProButton.layer.cornerRadius = topProButton.frame.height/2
    previousUserImageView.layer.cornerRadius = previousUserImageView.frame.height/2
    flipButton.layer.cornerRadius = flipButton.frame.height/2
    flipButton.layer.borderColor = UIColor.white.cgColor
    flipButton.layer.borderWidth = 2.0
    previousUserImageView.layer.borderColor = UIColor.white.cgColor
    previousUserImageView.layer.borderWidth = 2.0
    topProButton.layer.borderColor = UIColor.white.cgColor
    topProButton.layer.borderWidth = 2.0
    previewImageView.layer.shadowColor = UIColor.black.cgColor
    previewImageView.layer.shadowOffset = CGSize(width: 0, height: 0)
    previewImageView.layer.shadowOpacity = 0.55
//    previewImageView.layer.borderColor = UIColor(displayP3Red: 1, green: 1, blue: 1, alpha: 0.6).cgColor
//    previewImageView.layer.borderWidth = 3.0
    trackingView?.frame = CGRect(x: topProButton.center.x - 110, y: view.center.y - 190, width: 220, height: 220)
    rectOutline = trackingView?.frame
    if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized  {
      guard let lastAsset = PHAsset.fetchAssets(in: album.assetCollection, options: nil).lastObject else { return }
      fetchImage(asset: lastAsset) { (image) in
        self.previousUserImageView.image = image
      }
    }
    start()
    let launches = UserDefaults.standard.integer(forKey: "launches")
    guard launches > 1 else {
      guard launches == 1 else { return }
      //show layovers
      
      return
    }
    guard launches % 25 == 0 else { return }
    SKStoreReviewController.requestReview()
  }
  
  @IBAction func previousImageTapped(_ sender: UITapGestureRecognizer) {
    UIApplication.shared.open(URL(string:"photos-redirect://")!)
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
    
    trackingView?.frame = CGRect(x: topProButton.center.x - 110, y: view.center.y - 190, width: 220, height: 220)
    rectOutline = trackingView?.frame
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
    }
  }
  
  @IBAction func imageViewTapped(_ sender: Any) {
    userImageLock.toggle()
    guard userImageLock else { return }
    
    let albumCount = PHAsset.fetchAssets(in: album.assetCollection, options: nil).count
    
    guard albumCount < 300 || writeOverTen else {
      album.removeEldest()
      return
    }
    //SKPaymentQueue.default().restoreCompletedTransactions()
    
    
    let animateImageView = UIImageView(frame: previewImageView.frame)
    animateImageView.image = previewImageView.image
    animateImageView.alpha = 0.6
    animateImageView.contentMode = UIView.ContentMode.scaleAspectFit
    animateImageView.layer.cornerRadius = previewImageView.frame.height/2
    animateImageView.clipsToBounds = true
    animateImageView.layer.borderColor = UIColor.white.cgColor
    animateImageView.layer.borderWidth = 2.0
    view.addSubview(animateImageView)
    view.bringSubviewToFront(animateImageView)
    
    UIView.animate(withDuration: 0.65, delay: 0, options: .curveEaseIn, animations: {
      animateImageView.layer.cornerRadius = self.previousUserImageView.frame.height/2
      animateImageView.frame = self.previousUserImageView.frame
    }) { (completed) in
      guard completed else { return }
      self.previousUserImageView.image = animateImageView.image
      animateImageView.removeFromSuperview()
    }
    
    func writeImg() {
      guard let img =  previewImageView.image else { return }
      //UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
      previewImageView.image = img
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
      //view.bringSubviewToFront(tracker)
      UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut, animations: {
        self.previewImageView.layoutIfNeeded()
      }) { (completed) in
        guard completed else { return }
      }
      //view.layoutIfNeeded()
    }
    switch gr.state {
    case .began:
      reset()
      tracker.startingLocation = gr.location(in: view)
      guard userImageLock else { return }
      userImageLock = false
    case .changed:
      adjust()
    case .ended:
      rectOutline = tracker.frame
      view.insertSubview(tracker, at: 1)
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
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard let proOfferVC = segue.destination as? ProOfferViewController else { return }
    proOfferVC.product = subscriptionManager.products.last
    proOfferVC.album = album
  }
}

