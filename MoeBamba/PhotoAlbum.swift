//
//  PhotoAlbum.swift
//  MoeBamba
//
//  Created by John N Blanchard on 12/17/18.
//  Copyright © 2018 JNB. All rights reserved.
//

import Foundation
import Photos

extension UIViewController {
  func fetchImage(asset: PHAsset, completion: @escaping  (UIImage) -> ()) {
    let options = PHImageRequestOptions()
    options.version = .original
    PHImageManager.default().requestImageData(for: asset, options: options) {
      data, uti, orientation, info in
      guard let data = data, let image = UIImage(data: data) else { return }
      completion(image)
    }
  }
}

class CustomPhotoAlbum: NSObject {
  static let albumName = "Magnified Images"
  static let sharedInstance = CustomPhotoAlbum()
  
  var assetCollection: PHAssetCollection?
  
  var auth: PHAuthorizationStatus = .notDetermined
  
  override init() {
    super.init()
    
    if let assetCollection = fetchAssetCollectionForAlbum() {
      self.assetCollection = assetCollection
      return
    }
    
    if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.authorized {
      PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) -> Void in
        ()
      })
    }
    
    if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
      self.createAlbum()
    } else {
      //PHPhotoLibrary.requestAuthorization(requestAuthorizationHandler)
    }
  }
  
  public func requestAuth(completion: ()? = nil) {
    if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.authorized {
      PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) -> Void in
        self.createAlbum()
        completion
      })
    }
  }
  
  func requestAuthorizationHandler(status: PHAuthorizationStatus) {
    if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
      self.createAlbum()
    }
  }
  
  func count() -> Int {
    guard PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized else { return 0 }
    guard assetCollection != nil else { return 0 }
    return PHAsset.fetchAssets(in: assetCollection!, options: nil).count
  }
  
  func createAlbum() {
    PHPhotoLibrary.shared().performChanges({
      PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: CustomPhotoAlbum.albumName)   // create an asset collection with the album name
    }) { success, error in
      if success {
        self.assetCollection = self.fetchAssetCollectionForAlbum()
        self.auth = .authorized
      }
    }
  }
  
  func fetchAssetCollectionForAlbum() -> PHAssetCollection? {
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = NSPredicate(format: "title = %@", CustomPhotoAlbum.albumName)
    let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
    
    if let _: AnyObject = collection.firstObject {
      return collection.firstObject
    }
    return nil
  }
  
  func removeEldest(completion: ((Bool) -> ())? = nil) {
    guard PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized else { return }
    guard assetCollection != nil else { return }
    guard let first = PHAsset.fetchAssets(in: assetCollection!, options: nil).firstObject else { return }
    PHPhotoLibrary.shared().performChanges({
      PHAssetChangeRequest.deleteAssets([first] as NSFastEnumeration)
    }) { (complete, error) in
      completion?(complete)
    }
  }
  
  func save(image: UIImage) {
    guard PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized else {
      //requestAuth(completion: save(image: image))
      return
    }
    if assetCollection == nil {
      return                          // if there was an error upstream, skip the save
    }
    
    PHPhotoLibrary.shared().performChanges({
      let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
      let assetPlaceHolder = assetChangeRequest.placeholderForCreatedAsset
      let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection!)
      let enumeration: NSArray = [assetPlaceHolder!]
      albumChangeRequest!.addAssets(enumeration)
      
    }, completionHandler: nil)
  }
}
