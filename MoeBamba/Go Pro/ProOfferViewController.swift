//
//  ProOfferViewController.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/8/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import UIKit
import StoreKit

class ProOfferViewController: UIViewController {
  @IBOutlet weak var currentCapacityLabel: UILabel!
  
  var product: SKProduct?
  var album: CustomPhotoAlbum?
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    currentCapacityLabel.text = "\(album?.count() ?? 0) / 300"
  }
  
  @IBAction func xButtonTapped(_ sender: Any) {
    dismiss(animated: true, completion: nil)
  }
  
  @IBAction func proButtonTapped(_ sender: Any) {
    guard let firstProduct = product else { return }
    let payment = SKPayment(product: firstProduct)
    SKPaymentQueue.default().add(payment)
  }
}
