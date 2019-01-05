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
    guard let results = request.results?.first as? VNDetectedObjectObservation else { return }
    debugPrint("following tracked object at: ", results.boundingBox)
  }
  
  let album = CustomPhotoAlbum.sharedInstance
  
  var semaphore = DispatchSemaphore(value: 1)
  var userImageLock = false
  
  var rectOutline: CGRect?
  var sizeWidth = CGFloat(0)
  var sizeHeight = CGFloat(0)
  
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
      try? device?.lockForConfiguration()
      defer { device?.unlockForConfiguration() }
      guard let devicePoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: gr.location(in: gr.view)) else { return }
      device?.focusPointOfInterest = devicePoint
      device?.exposurePointOfInterest = devicePoint
    case .cancelled:
      reset()
    default:
      break
    }
  }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    guard let img = photo.cgImageRepresentation()?.takeUnretainedValue() else { return }
    let ci = CIImage(cgImage: img)
    guard let uiRect = rectOutline else { return }
    guard let metaRect = previewLayer?.metadataOutputRectConverted(fromLayerRect: uiRect) else { return }
    
    let outputRect = output.outputRectConverted(fromMetadataOutputRect: metaRect)
    
    /*
    let xRatio = CGFloat(img.width) / sizeWidth
    let yRatio = CGFloat(img.height) / sizeHeight
    
    let bigRect = CGRect(x: uiRect.origin.x*xRatio, y: uiRect.origin.y*yRatio, width: uiRect.width*xRatio, height: uiRect.height*yRatio)
    */
    let crop = ci.cropped(to: outputRect).oriented(forExifOrientation: 6)
    
    guard let cgCrop = CIContext(options: nil).createCGImage(crop, from: crop.extent) else { return }
    let cropUI = UIImage(cgImage: cgCrop)
    album.save(image: cropUI)
    previewImageView.image = cropUI
    debugPrint(img.height, img.width, crop.extent.width, crop.extent.height)
  }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    semaphore.wait()
    defer { semaphore.signal() }
    guard previewLayer != nil else { return }
    guard rectOutline != nil else { return }
    guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let wrongOrientationImage = CIImage(cvImageBuffer: buffer)
    var ciImg = wrongOrientationImage  //.oriented(forExifOrientation: 6)
    func adjustForCrop() -> CGRect {

      guard let metaRect = previewLayer?.metadataOutputRectConverted(fromLayerRect: rectOutline!) else { return CGRect.zero }
      

//      debugPrint("yinverseMetaRect: ", yInverseMetaRect)
      return output.outputRectConverted(fromMetadataOutputRect: metaRect)
      
//      return CGRect(x: metaRect.origin.x*ciImg.extent.width, y: metaRect.origin.y*ciImg.extent.height, width: metaRect.width*ciImg.extent.width, height: metaRect.height*ciImg.extent.height)
      
      let xRatio = CGFloat(ciImg.extent.width / sizeWidth)
      let yRatio = CGFloat(ciImg.extent.height / sizeHeight)
      /*
      let layerPositionRect = previewLayer?.metadataOutputRectConverted(fromLayerRect: rectOutline!)
      guard var candidate = layerPositionRect?.applying(transformsPortrait).applying(CGAffineTransform(translationX: 0, y: -1439)) else { return  CGRect.zero }
      let interpretedImageRect = CGRect(x: candidate.origin.x*sizeWidth, y: candidate.origin.y*sizeHeight, width: candidate.width*sizeWidth, height: candidate.height*sizeHeight)
      return interpretedImageRect
      */
      /*
       dxx = 5*3 (300 / 100) dxy = 50*2.5 (500/200)
       width1 = 300 height1 = 500
       dx1 = 5, dy1 = 50
       width2 = 100 height2 = 200
       
      */
      var newY = rectOutline!.origin.y
      var newX = rectOutline!.origin.x
      accountY: if rectOutline!.midY < sizeHeight / 2 {
        let calc = (sizeHeight / 2) - rectOutline!.midY
        newY = (sizeHeight / 2 ) + calc - (rectOutline!.height / 2)
        //difference below the axis is actually above the axis
      } else {
        guard rectOutline!.midY != sizeHeight / 2 else { break accountY }
        let calc = rectOutline!.midY - (sizeHeight / 2)
        newY = (sizeHeight / 2) - calc - (rectOutline!.height / 2)
        //difference above the axis is actually below the axis
      }
      
      
      //toododooooo
      accountX: if rectOutline!.midX < sizeWidth / 2 {
        let calc = (sizeWidth / 2) - rectOutline!.midX
        newX = rectOutline!.origin.x - 40
        debugPrint("x size small")
      } else {
        guard rectOutline!.midX != sizeWidth / 2 else { break accountX }
        debugPrint("x size big")
        let calc = rectOutline!.midX - (sizeWidth / 2)
        newX = rectOutline!.origin.x + 40
//        newX = (sizeWidth / 2) - calc - (rectOutline!.width / 2)
      }
      
      /*
      guard let topLeft = previewLayer?.captureDevicePointConverted(fromLayerPoint: CGPoint(x: rectOutline!.minX, y: rectOutline!.minY)) else { return CGRect.zero }
      
      newX = rectOutline!.origin.x - (rectOutline!.width/8)
      
      let metadataRect = CGRect(x: topLeft.x*sizeWidth, y: topLeft.y*sizeHeight, width: rectOutline!.width/sizeWidth, height: rectOutline!.height/sizeHeight)
      let interpreted  = captureOutput.outputRectConverted(fromMetadataOutputRect: metadataRect)
      return interpreted
      */
      
      return CGRect(x: newX, y: newY, width: rectOutline!.width, height: rectOutline!.height).applying(CGAffineTransform(scaleX: xRatio, y: yRatio))
      
      let rect1 = rectOutline!.applying(CGAffineTransform(scaleX: xRatio, y: yRatio))
      
      let rect = CGRect(x: rectOutline!.origin.x*xRatio, y:  (rectOutline!.origin.y*yRatio), width: rectOutline!.size.width*xRatio, height: rectOutline!.size.height*yRatio).applying(CGAffineTransform.init(scaleX: 1, y: -1))
      return rect1
    }
    //cropped to image -- need to check landscape
    let highlightedArea = adjustForCrop().applying(CGAffineTransform(translationX: 0, y: -ciImg.extent.height)).applying(CGAffineTransform(scaleX: 1, y: -1))
//    let yInverseMetaRect = metaRect.applying(CGAffineTransform(translationX: 0, y: -1)).applying(CGAffineTransform(scaleX: 1, y: 1))
    debugPrint("outputRect: ", highlightedArea)
    let img = ciImg.cropped(to: highlightedArea)
    DispatchQueue.main.async {
      guard !self.userImageLock else { return }
      guard let cgimg = CIContext(options: nil).createCGImage(img, from: img.extent) else { return }
      self.previewImageView.image = UIImage(cgImage: cgimg)
    
    }
    /*
    let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
    let request = VNTrackObjectRequest(detectedObjectObservation: VNDetectedObjectObservation(boundingBox: highlightedArea), completionHandler: visionHandler)
    do {
      try handler.perform([request])
    } catch {
      debugPrint(error)
    }
    */
  }
  
  func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
  }
}

