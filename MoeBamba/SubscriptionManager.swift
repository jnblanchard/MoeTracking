//
//  SubscriptionManager.swift
//  MoeBamba
//
//  Created by John N Blanchard on 1/7/19.
//  Copyright © 2019 JNB. All rights reserved.
//

import Foundation
import StoreKit
import UIKit

class SubscriptionManager: NSObject {
  static let shared = SubscriptionManager()
  
  var products: [SKProduct] = []
  
  override init() {
    super.init()
    let request = SKProductsRequest(productIdentifiers: Set(["MagnifyingGlassTool"]))
    request.delegate = self
    request.start()
  }
}

extension SubscriptionManager: SKProductsRequestDelegate {
  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    products = response.products
  }
}

extension ProOfferViewController: SKPaymentTransactionObserver {
  public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    guard let firstTransaction = transactions.last?.original else { return }
    switch firstTransaction.transactionState {
    case .purchased:
      dismiss(animated: true, completion: nil)
    case .restored:
      guard firstTransaction.original != nil else { return }
      dismiss(animated: true, completion: nil)
    default:
      break
    }
  }
}

extension MagnificationViewController: SKPaymentTransactionObserver {
  public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    guard let firstTransaction = transactions.last?.original else { return }
    switch firstTransaction.transactionState {
    case .purchased:
      writeOverTen = true
    case .purchasing:
      writeOverTen = false
    case .restored:
      guard firstTransaction.original != nil else { return }
      writeOverTen = true
    default:
      break
    }
    topProButton.isHidden = writeOverTen
  }
}
